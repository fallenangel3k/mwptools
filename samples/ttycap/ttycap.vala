/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

/* Based on the Multiwii UBLOX parser, GPL by a cast of thousands */

extern int open_serial(string dev, int baudrate);
//extern void set_fd_speed(int fd, int baudrate);
extern void close_serial(int fd);
extern string default_name();
extern unowned string get_error_text(int err, uint8[] buf, size_t len);

public class MWSerial : Object
{
    public int fd {private set; get;}
    private IOChannel io_read;
    public  bool available {private set; get;}
    private uint tag;
    public uint baudrate  {private set; get;}

    public static string devname = null;
    public static int brate = 38400;
    public static uint secs = 0;

    const OptionEntry[] options = {
        { "device", 'd', 0, OptionArg.STRING, out devname, "device name", "/dev/ttyUSB0"},
        { "baudrate", 'b', 0, OptionArg.INT, out brate, "Baud rate", "38400"},
        { "duration", 't', 0, OptionArg.INT, out secs, "Duration", "0"},
        {null}
    };

    public MWSerial()
    {
        available = false;
        fd = -1;
    }

    private void setup_reader(int fd)
    {
        try {
            io_read = new IOChannel.unix_new(fd);
            if(io_read.set_encoding(null) != IOStatus.NORMAL)
                    error("Failed to set encoding");
            tag = io_read.add_watch(IOCondition.IN|IOCondition.HUP|IOCondition.NVAL,
                                    device_read);
        } catch(IOChannelError e) {
            error("IOChannel: %s", e.message);
        }
    }

    private bool open(string device, int rate)
    {
        fd = open_serial(device, rate);
        if(fd < 0)
        {
            uint8 [] sbuf = new uint8[1024];
            var lasterr=Posix.errno;
            var s = get_error_text(lasterr, sbuf, 1024);
            stderr.printf("%s (%d)\n", s, lasterr);
            fd = -1;
            available = false;
        }
        else
        {
            available = true;
            setup_reader(fd);
        }
        return available;
    }

    ~MWSerial()
    {
        if(fd != -1)
            close();
    }

    public void close()
    {
        available=false;
        if(fd != -1)
        {
            if(tag > 0)
            {
                Source.remove(tag);
            }
            try  { io_read.shutdown(false); } catch {}
            close_serial(fd);
            fd = -1;
        }
    }

    private bool device_read(IOChannel gio, IOCondition cond) {
        uint8 buf[2048];
        size_t res;
        if((cond & (IOCondition.HUP|IOCondition.ERR|IOCondition.NVAL)) != 0)
        {
            available = false;
            return false;
        }
        else
        {
            res = Posix.read(fd,buf,2048);
            if(res < 0)
                return false;
            else
            {
                Posix.write(1, buf, res);
            }

        }
        return true;
    }

    public bool tty_open(string devname, int brate)
    {
        string [] parts;

        parts = devname.split ("@");
        if(parts.length == 2)
        {
            devname = parts[0];
            brate = int.parse(parts[1]);
        }
        stdout.printf("%s@%d\n", devname, brate);
        open(devname, brate);
        return available;
    }

    public static int main(string[] args)
    {
        try {
            var opt = new OptionContext("");
            opt.set_help_enabled(true);
            opt.add_main_entries(options, null);
            opt.parse(ref args);
        }
        catch (OptionError e) {
            stderr.printf("Error: %s\n", e.message);
            stderr.printf("Run '%s --help' to see a full list of available "+
                          "options\n", args[0]);
            return 1;
        }
        if(devname == null)
            devname = default_name();
        var msp = new MWSerial();
        if(msp.tty_open(devname, brate))
        {
            var loop = new MainLoop();
            if(secs > 0)
            {
                Timeout.add_seconds(secs, () => {
                        loop.quit();
                        return false;
                    });
            }
            loop.run();
        }
        return 0;
    }
}
