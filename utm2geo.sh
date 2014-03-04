#!/bin/bash

# Autor: Nelson Hereveri San Martín <nelson@hereveri.cl>

# Esta es una obra de creación libre bajo licencia Creative Commons con propiedades de Attribution y Share Alike
#
# Básicamente significa: El material creado por un artista puede ser distribuido, copiado y exhibido por terceros
# si se muestra en los créditos. Las obras derivadas tienen que estar bajo los mismos términos de licencia que el
# trabajo original.
#
# Extraído de http://www.creativecommons.cl/tipos-de-licencias/

if [ "$DEBUG" = "" ]; then
	DEBUG=0
fi

if [ "$SCALE" = "" ]; then
  SCALE=20
fi

PI=$(echo "scale=${SCALE}; 4 * a (1)" | bc -l)

##########
# Arrays #
##########
declare -a ELIPSOIDE
ELIPSOIDE[1]="WGS 1984"				# Nombre de elipsoide
ELIPSOIDE[2]=6378137.0        # semi-eje mayor
ELIPSOIDE[3]=6356752.314245   # semi-eje menor...
ELIPSOIDE[4]="Internacional 1969"
ELIPSOIDE[5]=6378160.0
ELIPSOIDE[6]=6356774.719
ELIPSOIDE[7]="Internacional de 1909/1924"
ELIPSOIDE[8]=6378388.0
ELIPSOIDE[9]=6356911.946

##################################
# Verificar existencia elipsoide #
##################################
CONTADOR_ELIPSOIDE=${#ELIPSOIDE[@]}
FLAG=$(echo "${CONTADOR_ELIPSOIDE} % 3" | bc)

if [ $CONTADOR_ELIPSOIDE -gt 0 -a "$FLAG" != "0" ]
then
	echo "Error en declaración de elipsoides. Revisar array ELIPSOIDE" >&2
	exit 1
fi

declare -a DATUMS
DATUMS[1]="WGS84"          # Datum name
DATUMS[2]=${ELIPSOIDE[1]}   # Elipsoide Datum...
DATUMS[3]="SAD69"
DATUMS[4]=${ELIPSOIDE[4]}
DATUMS[5]="PSAD56"
DATUMS[6]=${ELIPSOIDE[7]}

DATUMSELECT="${DATUMS[1]}"; export DATUMSELECT
DATUM=""; export DATUM
HUSO=""; export HUSO
HEMISFERIO=""; export HEMISFERIO
XCOORD=""; export XCOORD
YCOORD=""; export YCOORD
SEXADECIMAL=0; export SEXADECIMAL
ADDVALUE=0; export ADDVALUE
TECH=0; export TECH

#############
# Funciones #
#############
Help() {
	echo -e "USO:\n\t`basename $0` [-d <datum>] [-s] [-t] -h <huso> -z {N|S} <x-coord> <y-coord> " >&2
	echo -e "\t`basename $0` -H" >&2

	if [ $# -eq 0 ]; then
		return
	fi
	cat >&2 <<!

  -H          Muestra esta ayuda.
  -h          Huso a utilizar.
  -z          Hemisferio utilizado N ó S
  -d          Datum a utilizar. Por defecto $DATUMSELECT
  -t          Solo imprime las coordenadas en decimales
  -s          Latitud y Longitud en sexadecimal (grado y min enteros, segundos real N|S|E|W)
!
}

Tangente() {
  local VALUE=$(echo "scale=$SCALE; s($1) / c($1)" | bc -l)
  echo $VALUE
}

ArcoMeridional() {
  VALUE=$(echo "scale=$SCALE; (10000000.0 - $1) / 0.9996" | bc)
  echo $VALUE
}

Excentricidad() {
  local VALUE=$(echo "scale=$SCALE; sqrt ( ($1 * $1) - ($2 * $2) ) / $1" | bc -l)
  echo $VALUE
}

Excentricidad2Cuadrado() {
  local VALUE=$(echo "scale=$SCALE; ($1 * $1) / (1 - ( $1 * $1))" | bc -l)
  echo $VALUE
}

Mu() {
  local VALUE=$(echo "scale=$SCALE; $1 / ($2 * (1 - ($3*$3/4) - (3*$3*$3*$3*$3/64) - 5*$3*$3*$3*$3*$3*$3/256))" | bc)
  echo $VALUE
}

FunctionE1() {
  local VALUE=$(echo "scale=$SCALE; (1 - sqrt(1 - $1*$1))/(1 + sqrt(1 - $1*$1))" | bc)
  echo $VALUE
}

FunctionJ1() {
  local VALUE=$(echo "scale=$SCALE; 3*$1/2 - 27*$1*$1*$1/32" | bc)
  echo $VALUE
}

FunctionJ2() {
  local VALUE=$(echo "scale=$SCALE; 21*$1*$1/16 - 55*$1*$1*$1*$1/32" | bc)
  echo $VALUE
}

FunctionJ3() {
  local VALUE=$(echo "scale=$SCALE; 151*$1*$1*$1/96" | bc)
  echo $VALUE
}

FunctionJ4() {
  local VALUE=$(echo "scale=$SCALE; 1097*$1*$1*$1*$1/512" | bc)
  echo $VALUE
}

Footprint() {
  local VALUE=$(echo "scale=$SCALE; $1 + $2*s(2*$1) + $3*s(4*$1) + $4*s(6*$1) + $5*s(8*$1)" | bc -l)
  echo $VALUE
}

FunctionC1() {
  local VALUE=$(echo "scale=$SCALE; $1*c($2)*c($2)" | bc -l)
  echo $VALUE
}

FunctionT1() {
  local VALUE=$(echo "scale=$SCALE; $1*$1" | bc -l)
  echo $VALUE
}

FunctionR1() {
  local VALUE=$(echo "scale=$SCALE; $1*(1-$2*$2)/((1-$2*$2*s($3)*s($3))*sqrt(1-$2*$2*s($3)*s($3)))" | bc -l)
  echo $VALUE
}

FunctionN1() {
  local VALUE=$(echo "scale=$SCALE; $1/sqrt(1-$2*$2*s($3)*s($3))" | bc -l)
  echo $VALUE
}

FunctionD() {
  local VALUE=$(echo "scale=$SCALE; (500000.0 -$1)/($2*0.9996)" | bc -l)
  echo $VALUE
}

FunctionQ1() {
  local VALUE=$(echo "scale=$SCALE; $1*$2/$3" | bc -l)
  echo $VALUE
}

FunctionQ2() {
  local VALUE=$(echo "scale=$SCALE; $1*$1/2" | bc -l)
  echo $VALUE
}

FunctionQ3() {
  local VALUE=$(echo "scale=$SCALE; (5 + 3*$1 + 10*$2 - 4*$2*$2 -9*$3)*$4*$4*$4*$4/24" | bc -l)
  echo $VALUE
}

FunctionQ4() {
  local VALUE=$(echo "scale=$SCALE; (61 + 90*$1 + 298*$2 + 45*$1*$1 - 3*$2*$2 - 252*$3)*$4*$4*$4*$4*$4*$4/720" | bc -l)
  echo $VALUE
}

FunctionQ6() {
  local VALUE=$(echo "scale=$SCALE; (1 + 2*$1 + $2)*$3*$3*$3/6" | bc -l)
  echo $VALUE
}

FunctionQ7() {
  local VALUE=$(echo "scale=$SCALE; (5 - 2*$1 + 28*$2 - 3*$1*$1 + 8*$3 + 24*$2*$2)*$4*$4*$4*$4*$4/120" | bc -l)
  echo $VALUE
}

CalcularLatitud() {
  local VALUE=$(echo "scale=$SCALE; 180*($1 - $2*($3 + $4 + $5))/$PI" | bc -l)
  if [ "$6" = "S" ]; then
    VALUE=$(echo "$VALUE * -1" | bc)
  fi
  echo $VALUE
}

MeridianoCentral() {
  local VALUE=$(($1 * 6 - 183))
  echo $VALUE
}

CalcularLongitud() {
  local VALUE=$(echo "scale=$SCALE; $1 - 180*(($2 - $3 + $4)/c($5))/$PI" | bc -l)
  echo $VALUE
}

Sexadecimal() {
  local MINUS=0
  local VALUE=""
  local SIMB=""
  if [ "`echo $1 | cut -b 1`" = "-" ]; then
    MINUS=1
    VALUE=$(echo $1 | cut -b 2-)
  else
    VALUE="$1"
  fi
  DEG=$(echo $VALUE | cut -d "." -f 1)
  VALUE=$(echo "scale=$SCALE; ($VALUE - $DEG)*60" | bc)
  MIN=$(echo $VALUE | cut -d "." -f 1)
  VALUE=$(echo "scale=$SCALE; ($VALUE - $MIN)*60" | bc)
  if [ $2 -eq 0 ]; then # Lat
    if [ $MINUS -eq 0 ]; then
      SIMB="N"
    else
      SIMB="S"
    fi
  else # Long
    if [ $MINUS -eq 0 ]; then
      SIMB="E"
    else
      SIMB="W"
    fi
  fi
  echo "$DEG $MIN $VALUE $SIMB"
}

##############
# Parámetros #
##############
set -- `getopt :d:h:z:Hst $*`
if [ $? -ne 0 ]; then
    Help
    exit 1
fi
while [ $1 != "--" ]
do
    case $1 in
        -H) Help all; exit 0;;
        -d) DATUMSELECT="$2" ; shift 2;;
				-h) HUSO="$2" ; shift 2;;
				-s) SEXADECIMAL=1; shift;;
        -t) TECH=1; shift;;
        -z) HEMISFERIO="$2" ; shift 2;;
        *)	echo "Opción inválida: $1" >&2; exit 1;;
    esac
done
shift

if [ "$#" -eq 2 -a "$HUSO" != "" -a "$HEMISFERIO" != "" ]; then
  XCOORD="$1"
  YCOORD="$2"
else
	Help
	exit 1
fi

for j in `seq 1 2 ${#DATUMS[@]}`
do
  if [ "$DATUMSELECT" = "${DATUMS[j]}" ]; then
    for i in `seq 1 3 ${#ELIPSOIDE[@]}`
    do
      if [ "${DATUMS[j+1]}" = "${ELIPSOIDE[${i}]}" ]; then
        ELIPSOIDE="${ELIPSOIDE[${i}]}"
        FLAG=1
        A="${ELIPSOIDE[${i}+1]}"
        B="${ELIPSOIDE[${i}+2]}"
        EXC1=$(Excentricidad ${ELIPSOIDE[${i}+1]} ${ELIPSOIDE[${i}+2]})
        EXC2CUAD=$(Excentricidad2Cuadrado $EXC1)
      fi
    done
    break
  fi
done

if [ $FLAG -ne 1 ]; then
  echo "Error Datum $DATUMSELECT no definido"
  exit 1
fi

MERIDIANOCENTRAL=$(MeridianoCentral $HUSO)
ARCOMERIDIONAL=$(ArcoMeridional $YCOORD)
MU=$(Mu $ARCOMERIDIONAL $A $EXC1)
E1=$(FunctionE1 $EXC1)
J1=$(FunctionJ1 $E1)
J2=$(FunctionJ2 $E1)
J3=$(FunctionJ3 $E1)
J4=$(FunctionJ4 $E1)
FOOTPRINT=$(Footprint $MU $J1 $J2 $J3 $J4)
C1=$(FunctionC1 $EXC2CUAD $FOOTPRINT)
FPTAN=$(Tangente $FOOTPRINT)
T1=$(FunctionT1 $FPTAN)
R1=$(FunctionR1 $A $EXC1 $FOOTPRINT)
N1=$(FunctionN1 $A $EXC1 $FOOTPRINT)
D=$(FunctionD $XCOORD $N1)
Q1=$(FunctionQ1 $N1 $FPTAN $R1)
Q2=$(FunctionQ2 $D)
Q3=$(FunctionQ3 $T1 $C1 $EXC2CUAD $D)
Q4=$(FunctionQ4 $T1 $C1 $EXC2CUAD $D)
Q5="$D"
Q6=$(FunctionQ6 $T1 $C1 $D)
Q7=$(FunctionQ7 $C1 $T1 $EXC2CUAD $D)
LATITUD=$(CalcularLatitud $FOOTPRINT $Q1 $Q2 $Q3 $Q4 $HEMISFERIO | bc)
LONGITUD=$(CalcularLongitud $MERIDIANOCENTRAL $Q5 $Q6 $Q7 $FOOTPRINT | bc)

LAT_TEST=$(echo $LATITUD | cut -d "." -f 1 | bc)
LNG_TEST=$(echo $LONGITUD | cut -d "." -f 1 | bc)

if [ $LAT_TEST -gt 90 -o $LAT_TEST -lt -90 -o $LNG_TEST -gt 180 -o $LNG_TEST -lt -180 ]; then
  echo "¡Error en parámetros!" >&2
  exit -1
fi

if [ "$SEXADECIMAL" = "1" ]; then
  echo "Sexadecimal" >&2
  LATITUD=$(Sexadecimal $LATITUD 0)
  LONGITUD=$(Sexadecimal $LONGITUD 1)
fi

# Parámetros correctos
if [ $DEBUG -eq 1 ]; then
  cat >&2 <<!
  Datum: $DATUMSELECT
  Elipsoide: $ELIPSOIDE
  Eje Polar: $B
  Radio Ecuatorial: $A
  Huso: $HUSO
  Hemisferio: $HEMISFERIO
  Meridiano central: $MERIDIANOCENTRAL
  Coord: $XCOORD, $YCOORD
  Arco Meridional: $ARCOMERIDIONAL
  Excentricidad: $EXC1
  Segunda excentricidad cuadrado: $EXC2CUAD
  Mu: $MU
  E1: $E1
  J1: $J1
  J2: $J2
  J3: $J3
  J4: $J4
  FOOTPRINT: $FOOTPRINT
  C1: $C1
  T1: $T1
  R1: $R1
  N1: $N1
  D: $D
  Q1: $Q1
  Q2: $Q2
  Q3: $Q3
  Q4: $Q4
  Q5: $Q5
  Q6: $Q6
  Q7: $Q7
  LATITUD: $LATITUD
  LONGITUD: $LONGITUD

!
elif [ $TECH -eq 0 ]; then
  echo -e "Datum: $DATUMSELECT\nElipsoide: $ELIPSOIDE\nHuso: $HUSO\nHemisferio: $HEMISFERIO\nLatitud: $LATITUD\nLongitud: $LONGITUD"
else
  echo "$LATITUD $LONGITUD"
fi

exit 0
# vim: nu: sw=2: ts=2
