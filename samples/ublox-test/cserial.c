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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>

#if !defined( WIN32 )
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <termios.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <errno.h>

void set_fd_speed(int fd, int baudrate)
{
    struct termios tio;
    memset (&tio, 0, sizeof(tio));
    tcgetattr(fd, &tio);
    switch (baudrate)
    {
        case 0:      baudrate=B115200; break;
        case 2400:   baudrate=B4800; break;
        case 4800:   baudrate=B4800; break;
        case 9600:   baudrate=B9600; break;
        case 19200:  baudrate=B19200; break;
        case 38400:  baudrate=B38400; break;
        case 57600:  baudrate=B57600; break;
        case 115200: baudrate=B115200; break;
        case 230400: baudrate=B230400; break;
    }
    cfsetispeed(&tio,baudrate);
    cfsetospeed(&tio,baudrate);
    tcsetattr(fd,TCSANOW,&tio);
}

int open_serial(char *device, uint baudrate)
{
    int fd;
    fd = open(device, O_RDWR|O_NOCTTY);
    if(fd != -1)
    {
        struct termios tio;
        memset (&tio, 0, sizeof(tio));
        tcgetattr(fd, &tio);
        cfmakeraw(&tio);
        tio.c_cc[VTIME] = 0;
        tio.c_cc[VMIN] = 0;
        tcsetattr(fd,TCSANOW,&tio);
        set_fd_speed(fd, baudrate);
    }
    return fd;
}

void close_serial(int fd)
{
    tcflush(fd, TCIOFLUSH);
    close(fd);
}

char *get_error_text (int errnum, char *buf, size_t buflen)
{
    *buf = 0;
    strerror_r(errnum, buf, buflen);
    return buf;
}

#else

/** COMPLETELY untested **/

#include <windows.h>
static HANDLE hfd;
#define pipe(__p1) _pipe(__p1,4096,_O_BINARY)

char *get_error_text (int dummy, char *pBuf, size_t bufSize)
{
    DWORD retSize;
    LPTSTR pTemp=NULL;

    if (bufSize < 16) {
        if (bufSize > 0) {
            pBuf[0]='\0';
        }
        return(pBuf);
     }
    retSize=FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER|
                          FORMAT_MESSAGE_FROM_SYSTEM|
                          FORMAT_MESSAGE_ARGUMENT_ARRAY,
                          NULL,
                          GetLastError(),
                          LANG_NEUTRAL,
                          (LPTSTR)&pTemp,
                          0,
                          NULL );
    if (!retSize || pTemp == NULL) {
          pBuf[0]='\0';
    }
    else {
        pTemp[strlen(pTemp)-2]='\0'; //remove cr and newline character
        sprintf(pBuf,"%0.*s (0x%x)",bufSize-16,pTemp,GetLastError());
        LocalFree((HLOCAL)pTemp);
    }
    return(pBuf);
}

int open_serial(const char *device, int baudrate)
{
    int fd=-1;
    hfd = CreateFile(device,
                            GENERIC_READ | GENERIC_WRITE,
                            0,
                            NULL,
                            OPEN_EXISTING,
                            FILE_ATTRIBUTE_NORMAL,
                            NULL);

    if(hfd != INVALID_HANDLE_VALUE)
    {
        fd = _open_osfhandle((long)hfd, O_RDWR);
        COMMTIMEOUTS ctout;
        GetCommTimeouts(hfd, &ctout);
        ctout.ReadIntervalTimeout = 100;
        ctout.ReadTotalTimeoutMultiplier = 0;
        ctout.ReadTotalTimeoutConstant = 100;
        SetCommTimeouts(hfd, &ctout);
        set_fd_speed(fd, baudrate);
    }
    return fd;
}

set_fd_speed(int fd, int baudrate)
{
    fd=fd;
    DCB dcb = {0};
    BOOL res = FALSE;
    char act = 'g';

    dcb.DCBlength = sizeof(DCB);

    if ((res = GetCommState(hfd, &dcb)))
    {
        act = 's';
        dcb.ByteSize=8;
        dcb.StopBits=ONESTOPBIT;
        dcb.Parity=NOPARITY;
        switch (baudrate)
        {
            case 0:
            case 115200:
                dcb.BaudRate=CBR_115200;
                break;
            case 2400:
                dcb.BaudRate=CBR_2400;
                break;
            case 4800:
                dcb.BaudRate=CBR_4800;
                break;
            case 9600:
                dcb.BaudRate=CBR_9600;
                break;
            case 19200:
                dcb.BaudRate=CBR_19200;
                break;
            case 38400:
                dcb.BaudRate=CBR_38400;
                break;
            case 57600:
                dcb.BaudRate=CBR_57600;
                break;
        }
        res = SetCommState(hfd, &dcb);
    }
    if(!res)
    {
        char mbuf[1024];
        fprintf(stderr,"Failed to %cet baud rate\n");
        fprintf(stderr,"%s\n", get_error_text(0, mbuf, sizeof(mbuf)));
    }
}

void close_serial(int fd)
{
        /* Correct ?? , close both ?? */
    CloseHandle(hfd);
    hfd = 0;
    close(fd);
}
#endif

int cf_pipe(int *fds)
{
    return pipe(fds);
}

int cf_pipe_close(int fd)
{
    return close(fd);
}

char * default_name(void)
{
#ifdef __linux__
    return "/dev/ttyUSB0";
#else
    return NULL;
#endif
}
