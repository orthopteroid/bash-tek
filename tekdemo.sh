#! /bin/bash

# tek 4014 graphics in an xterm window using bash
# launch with: xterm -t -e ./tekdemo.sh
# orthopteroid@gmail.com (29 september 2008 + recent additions)

# primary tek device drawing logic
# surface is 1023 x 779 in vector coordinates (scales with xterm window) with 0 0 located in bottom left
# ftp://ftp.unc.edu/pub/empd/products/EDSS/test/public_domain/plplot_old/drivers/tek.c
# http://rtfm.etla.org/xterm/ctlseq.html
function _clear { echo -en "\x1B\x0C" ; }
function _solidline { echo -en "\x1B\x68" ; }
function _dashedline { echo -en "\x1B\x69" ; }
function _smallfont { echo -en "\x1B\x3B" ; }
function _largefont { echo -en "\x1B\x38" ; }
function _endplot { echo -en "\x1F" ; }
function _text { _endplot ; echo -ne $1 ; }
function _penup { echo -en "\x1D" ; }
# todo: optimize this to a one liner printf...
function _makevect {
	echo -en \\x`printf "%x" $(( ($2 >> 5) + 32 ))`
	echo -en \\x`printf "%x" $(( ($2 & 31) + 96 ))`
	echo -en \\x`printf "%x" $(( ($1 >> 5) + 32 ))`
	echo -en \\x`printf "%x" $(( ($1 & 31) + 64 ))`
	echo -en '\x00'
}

###################################################

# drawing logic, with state.
lastx=0 ; lasty=0
function _vect { lastx=$1 ; lasty=$2 ; _makevect $lastx $lasty ; }
function _moveto { _penup ; _vect $1 $2 ; }
function _move { _penup ; _vect $(( $lastx + $1 )) $(( $lasty + $2 )); }
function _drawto { _vect $1 $2; }
function _draw { _vect $(( $lastx + $1 )) $(( $lasty + $2 )); }

###################################################
# game code uses fixedpoint arithmetic:
# tens and ones digits are tenths and hundredths

# fixedpoint trig tables with 20 graduations
sintable=(  0 31 58 80 94 99  94  80  58  31   0 -31 -58 -80 -94 -99 -94 -80 -58 -31 )
costable=( 99 94 80 58 31  0 -31 -58 -80 -94 -99 -94 -80 -58 -31   0  31  58  80  94 )

# fixedpoint shape language:
# M is Move, D is Draw, T is Text, R is Rotation, S is scale
# X is AbsoluteMove, W is AbsoluteDraw
# bash array passing trick from http://ubuntuforums.org/showthread.php?t=652303
function _drawshape()
{
	shape=( "$@" ) ; shape_tokens=${#shape[@]} ; token=0
	shapex=0 ; shapey=0 ; shapex1=0 ; shapey1=0 ; shaper=0 ; shapes=100
	while [ "$token" -lt "$shape_tokens" ]
	do
		shapeop=${shape[$token]} ; token=$[$token+1]
		if [ "$shapeop" = "S" ] ; then   shapes=${shape[$token]} ; token=$[$token+1]
		elif [ "$shapeop" = "R" ] ; then shaper=${shape[$token]} ; token=$[$token+1]
		elif [ "$shapeop" = "T" ] ; then  _text ${shape[$token]} ; token=$[$token+1]
		else
			shapex=${shape[$token]} ; token=$[$token+1]
			shapey=${shape[$token]} ; token=$[$token+1]

			# rotation with fixedpoint renormalization
			shapex1=$[ $shapes * ($shapex * costable[$shaper] - $shapey * sintable[$shaper]) / 10000 ]
			shapey1=$[ $shapes * ($shapey * costable[$shaper] + $shapex * sintable[$shaper]) / 10000 ]

			if [ "$shapeop" = "M" ] ; then   _move $[$shapex1/100] $[$shapey1/100]
			elif [ "$shapeop" = "D" ] ; then _draw $[$shapex1/100] $[$shapey1/100]
			elif [ "$shapeop" = "X" ] ; then _moveto $[$shapex1/100] $[$shapey1/100]
			elif [ "$shapeop" = "W" ] ; then _drawto $[$shapex1/100] $[$shapey1/100]
			fi
		fi
	done
}

# positions all fixed point
winl=500 ; winb=500 ; wint=76000 ; winr=50000
worldshape=( X $winl $winb W $winr $winb W $winr $wint W $winl $wint W $winl $winb )
rockshape=( S 550 M 0 99 D 31 94 D 58 80 D 80 58 D 94 31 D 99 0 D 94 -31 D 58 -80 D 31 -94 D 0 -99 D -58 -80 D -80 -58 D -94 -31 D -99 0 D -94 31 D -80 58 D -58 80 D -31 94 D 0 99 )
rocketshape=( M 1500 000 D -1500 500 D 000 -1000 D 1500 500 )

x=$[$winr/2] ; y=$[$wint/2] ; direction=0 ; accel=2
rockx=$[$winr/2] ; rocky=$[$wint/2] ; rockd=3 ; rocka=1

_clear
_smallfont
_solidline

while true; do
	_clear
	_moveto 0 0
	_text "\nOrthopteroid bids you Welcome!\nCommands are: z x o l\n\n\nFixed-point position: $x $y\nDirection: $direction\nAcceleration: $accel"
	_drawshape "${worldshape[@]}"
	_moveto $[$x/100] $[$y/100] ; _drawshape "R" "${direction}" "${rocketshape[@]}"
	_moveto $[$rockx/100] $[$rocky/100] ; _drawshape "R" "${rockd}" "${rockshape[@]}"

	tput cup 1 1
	key=" "
	read -s -t1 -n1 key

	# player controls
	if [ "$key" = "x" ] ; then direction=$[$direction-1]
	elif [ "$key" = "z" ] ; then direction=$[$direction+1]
	elif [ "$key" = "o" ] ; then accel=$[accel+1]
	elif [ "$key" = "l" ] ; then accel=$[accel-1]
	fi
	
	# clip player controls
	if [ $direction -gt 19 ]; then direction=0; elif [ $direction -lt 0 ]; then direction=19; fi
	if [ $accel -gt 5 ]; then accel=5; elif [ $accel -lt 0 ]; then accel=0; fi

	# move player
	x=$[$x + 5 * $accel * costable[$direction]] ; y=$[$y + 5 * $accel * sintable[$direction]]

	# clip player position
	if [ $x -gt $winr ]; then x=$winl; elif [ $x -lt $winl ]; then x=$winr; fi
	if [ $y -gt $wint ]; then y=$winb; elif [ $y -lt $winb ]; then y=$wint; fi

	# move rock
	rockx=$[$rockx + 5 * $rocka * costable[$rockd]] ; rocky=$[$rocky + 5 * $rocka * sintable[$rockd]]
	
	# clip rock position
	if [ $rockx -gt $winr ]; then rockx=$winl; elif [ $rockx -lt $winl ]; then rockx=$winr; fi
	if [ $rocky -gt $wint ]; then rocky=$winb; elif [ $rocky -lt $winb ]; then rocky=$wint; fi
done

_endplot
