/***********************************************************************
*                                                                      *
*               This software is part of the ast package               *
*          Copyright (c) 1985-2013 AT&T Intellectual Property          *
*                      and is licensed under the                       *
*                 Eclipse Public License, Version 1.0                  *
*                    by AT&T Intellectual Property                     *
*                                                                      *
*                A copy of the License is available at                 *
*          http://www.eclipse.org/org/documents/epl-v10.html           *
*         (with md5 checksum b35adb5213ca9657e911e9befb180842)         *
*                                                                      *
*              Information and Software Systems Research               *
*                            AT&T Research                             *
*                           Florham Park NJ                            *
*                                                                      *
*               Glenn Fowler <glenn.s.fowler@gmail.com>                *
*                    David Korn <dgkorn@gmail.com>                     *
*                     Phong Vo <phongvo@gmail.com>                     *
*                                                                      *
***********************************************************************/
#pragma prototyped

#include <tv.h>
#include <tm.h>
#include <error.h>

#include "FEATURE/tvlib"

#if !_lib_nanosleep && !_lib_usleep
# if _lib_select
#  if _sys_select
#   include <sys/select.h>
#  else
#   include <sys/socket.h>
#  endif
# elif _lib_poll_notimer
#  undef _lib_poll
# elif _lib_poll
#  include <poll.h>
# endif
#endif

#define NANOSECONDS 1000000000L

/*
 * sleep for tv
 * non-zero exit if sleep did not complete
 * with remaining time in rv
 *
 * NOTE: some systems hide nanosleep() outside of libc
 */

int
tvsleep(register const Tv_t* tv, register Tv_t* rv)
{

	int		r;

#if _lib_nanosleep

	struct timespec	stv;
	struct timespec	srv;

	stv.tv_sec = tv->tv_sec;
	stv.tv_nsec = tv->tv_nsec;
	if ((r = nanosleep(&stv, &srv)) && errno == EINTR && rv)
	{
		rv->tv_sec = srv.tv_sec;
		rv->tv_nsec = srv.tv_nsec;
	}
	return r;

#else

	Tv_t		bv;

	tvgettime(&bv);
	{

#if _lib_select

	struct timeval tvSleep = { tv->tv_sec, tv->tv_nsec / 1000 };
	if (tv->tv_nsec % 1000)
		++tvSleep.tv_usec;

	r = select(0, NiL, NiL, NiL, &tvSleep);

#else

	uint32_t	s = tv->tv_sec;
	uint32_t	n = tv->tv_nsec;
	unsigned int	t;

#if _lib_usleep

	if (s < (0x7fffffff / 1000000))
	{
		int	oerrno;

		oerrno = errno;
		errno = 0;
		usleep(s * 1000000 + n / 1000);
		if (!errno)
		{
			errno = oerrno;
			return 0;
		}
	}
	else
	{

#endif

		if (s += (n + 999999999L) / 1000000000L)
		{
			while (s)
			{
				if (s > UINT_MAX)
				{
					t = UINT_MAX;
					s -= UINT_MAX;
				}
				else
				{
					t = s;
					s = 0;
				}
				if (t = sleep(t))
				{
					if (rv)
					{
						rv->tv_sec = s + t;
						rv->tv_nsec = 0;
					}
					return -1;
				}
			}
			return 0;
		}

#if _lib_usleep

		if (t = (n + 999L) / 1000L)
		{
			int	oerrno;

			oerrno = errno;
			errno = 0;
			usleep(t);
			if (!errno)
			{
				errno = oerrno;
				return 0;
			}
		}
	}

#elif _lib_poll

	struct pollfd		pfd;
	int			t;

	if (!(t = (n + 999999L) / 1000000L))
		t = 1;
	r = poll(&pfd, 0, t);

#endif

#endif

	}

/* Ascertain whether we actually slept for a sufficient time.
 * It is preferable to sleep a little more than necessary than too little.
 */
	{
		struct timespec tsAfter;
		long sec, nsec;

		tvgettime(&tsAfter);

		/* Calculate seconds left to sleep */
		sec = (long)(tv->tv_sec + tv->tv_nsec / NANOSECONDS) -
			((long)tsAfter.tv_sec - (long)bv.tv_sec);

		/* Calculate nanoseconds left to sleep */
		nsec = (long)(tv->tv_nsec % NANOSECONDS) -
			((long)tsAfter.tv_nsec - (long)bv.tv_nsec);
		if (nsec >= NANOSECONDS)
		{
			++sec;
			nsec -= NANOSECONDS;
		}
		else if (nsec < 0)
		{
			--sec;
			nsec += NANOSECONDS;
		}

		if (sec >= 0 && (sec > 0 || nsec > 0))
		{
			if (rv)
			{
				rv->tv_sec  = sec;
				rv->tv_nsec = nsec;
			}
			return -1;
		}
	}
	return r;

#endif

}
