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
LATITUD=""; export LATITUD
LONGITUD=""; export LONGITUD
SEXADECIMAL=0; export SEXADECIMAL
ADDVALUE=0; export ADDVALUE
TECH=0; export TECH

#############
# Funciones #
#############
Help() {
	echo -e "USO:\n\t`basename $0` [-d <datum>] [-h <huso>] [-t] <latitud> N|S <longitud> E\W" >&2
	echo -e "\t`basename $0` [-d <datum>] [-h <huso>] [-t] -s <lat-grado> <lat-min> <lat-seg> N|S <long-grado> <long-min> <long-seg> E|W" >&2
	echo -e "\t`basename $0` -H" >&2

	if [ $# -eq 0 ]; then
		return
	fi
	cat >&2 <<!

  -H          Muestra esta ayuda.
  -d          Datum a utilizar. Por defecto $DATUMSELECT
  -h          Huso a forzar. Por defecto se calcula el huso según coordenadas. Mientras más lejano el uso respecto al adecuado peor precisión.
  -t          Solo imprime las partes enteras de las coordenadas X e Y
  -s          Latitud y Longitud en sexadecimal (grado y min enteros, segundos real)
!
}

Excentricidad() {
  local VALUE=$(echo "scale=$SCALE; sqrt ( ($1 * $1) - ($2 * $2) ) / $1" | bc -l)
  echo $VALUE
}

Excentricidad2() {
  local VALUE=$(echo "scale=$SCALE; sqrt ( ($1 * $1) - ($2 * $2) ) / $2" | bc -l)
  echo $VALUE
}

RadioPolar() {
  local VALUE=$(echo "scale=$SCALE; $1 * $1 / $2" | bc)
  echo $VALUE
}

Aplanamiento() {
  local VALUE=$(echo "scale=$SCALE; ($1 - $2) / $1" | bc)
  echo $VALUE
}

Sexadecimal2Decimal() {
  local VALUE=$(echo "scale=${SCALE}; $1 + $2 / 60 + $3 / 3600" | bc)
  echo $VALUE
}

Decimal2Radian() {
  local VALUE=$(echo "scale=${SCALE}; $1 * $PI / 180" | bc)
  echo $VALUE
}

CalculaHuso() {
  local VALUE=$(echo "scale=${SCALE}; ($1 / 6) + 31" | bc)
  echo $VALUE | cut -d "." -f 1
}

MeridianoCentral() {
  local VALUE=$(($1 * 6 - 183))
  echo $VALUE
}

DistanciaAngular() {
  local VALUE=$(echo "scale=$SCALE; $1 - ($2 * $PI / 180)" | bc)
  echo $VALUE
}

Tangente() {
  local VALUE=$(echo "scale=$SCALE; s($1) / c($1)" | bc -l)
  echo $VALUE
}

Function1() {
  local VALUE=$(echo "scale=$SCALE; c($1) * s($2)" | bc -l)
  echo $VALUE
}

Ksi() {
  local VALUE=$(echo "scale=$SCALE; (1/2)*l((1 + $1)/(1 - $1))" | bc -l)
  echo $VALUE
}

Ita() {
  local TMP=$(Tangente $1)
  local VALUE=$(echo "scale=$SCALE; a($TMP / c ($2)) - $1" | bc -l)
  echo $VALUE
}

Ni() {
  local VALUE=$(echo "scale=$SCALE; $1/(sqrt(1+$2*$2*c($3)*c($3)))*0.9996" | bc -l)
  echo $VALUE
}

Zeta() {
  local VALUE=$(echo "scale=$SCALE; (($1*$1)/2)*$2*$2*c($3)*c($3)" | bc -l)
  echo $VALUE
}

FunctionA1() {
  local VALUE=$(echo "scale=$SCALE; s(2*$1)" | bc -l)
  echo $VALUE
}

FunctionA2() {
  local VALUE=$(echo "scale=$SCALE; $1*c($2)*c($2)" | bc -l)
  echo $VALUE
}

FunctionJ2() {
  local VALUE=$(echo "scale=$SCALE; $1+$2/2" | bc)
  echo $VALUE
}

FunctionJ4() {
  local VALUE=$(echo "scale=$SCALE; (3*$1+$2)/4" | bc)
  echo $VALUE
}

FunctionJ6() {
  local VALUE=$(echo "scale=$SCALE; (5*$1+$2*c($3)*c($3))/3" | bc -l)
  echo $VALUE
}

Alpha() {
  local VALUE=$(echo "scale=$SCALE; (3/4)*$1*$1" | bc)
  echo $VALUE
}

Beta() {
  local VALUE=$(echo "scale=$SCALE; (5/3)*$1*$1" | bc)
  echo $VALUE
}

Gamma() {
  local VALUE=$(echo "scale=$SCALE; (35/27)*$1*$1*$1" | bc)
  echo $VALUE
}

FunctionB() {
  local VALUE=$(echo "scale=$SCALE; 0.9996*$1*($2-($3*$4)+($5*$6)-($7*$8))" | bc)
  echo $VALUE
}

CoordX() {
  local VALUE=$(echo "scale=$SCALE; $1*$2*(1+($3/3))+500000" | bc)
  echo $VALUE
}

CoordY() {
  local VALUE=$(echo "scale=$SCALE; $1*$2*(1+$3)+$4+$5" | bc)
  echo $VALUE
}

##############
# Parámetros #
##############
set -- `getopt :d:h:Hst $*`
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
        *)	echo "Opción inválida: $1" >&2; exit 1;;
    esac
done
shift

if [ $SEXADECIMAL -eq 0 -a $# -eq 4 ]; then
  LATITUD="$1"
  if [ "$2" = "S" ]; then
    ADDVALUE=10000000
    LATITUD="-${LATITUD}"
  fi
  LONGITUD="$3"
  if [ "$4" = "W" ]; then
    LONGITUD=$(echo "scale=$SCALE; $LONGITUD * -1" | bc)
  fi
elif [ $SEXADECIMAL -eq 1 -a $# -eq 8 ]; then
	LATITUD=$(Sexadecimal2Decimal $1 $2 $3)
  if [ "$4" = "S" ]; then
    ADDVALUE=10000000
    LATITUD="-${LATITUD}"
  fi
	LONGITUD=$(Sexadecimal2Decimal $5 $6 $7)
  if [ "$8" = "W" ]; then
    LONGITUD=$(echo "scale=$SCALE; $LONGITUD * -1" | bc)
  fi
else
	Help
	exit 1
fi

if [ "$LATITUD" = "" -o "$LONGITUD" = "" ]
then
	echo "Faltan parametros" >&2
	Help all
	exit 2
fi

LATRAD=$(Decimal2Radian $LATITUD)
LONRAD=$(Decimal2Radian $LONGITUD)

for j in `seq 1 2 ${#DATUMS[@]}`
do
  if [ "$DATUMSELECT" = "${DATUMS[j]}" ]; then
    for i in `seq 1 3 ${#ELIPSOIDE[@]}`
    do
      if [ "${DATUMS[j+1]}" = "${ELIPSOIDE[${i}]}" ]; then
        ELIPSOIDE="${ELIPSOIDE[${i}]}"
        FLAG=1
        EXC1=$(Excentricidad ${ELIPSOIDE[${i}+1]} ${ELIPSOIDE[${i}+2]})
        EXC2=$(Excentricidad2 ${ELIPSOIDE[${i}+1]} ${ELIPSOIDE[${i}+2]})
        RADPOLAR=$(RadioPolar ${ELIPSOIDE[${i}+1]} ${ELIPSOIDE[${i}+2]})
        APLANAMIENTO=$(Aplanamiento ${ELIPSOIDE[${i}+1]} ${ELIPSOIDE[${i}+2]})
      fi
    done
    break
  fi
done

if [ $FLAG -ne 1 ]; then
  echo "Error Datum $DATUM no definido"
  exit 1
fi

if [ "$HUSO" = "" ]; then
  HUSO=$(CalculaHuso $LONGITUD)
fi

MERIDIANO_CENTRAL=$(MeridianoCentral $HUSO)
DISTANCIA_ANGULAR=$(DistanciaAngular $LONRAD $MERIDIANO_CENTRAL)
A=$(Function1 $LATRAD $DISTANCIA_ANGULAR)
XI=$(Ksi $A)
ETA=$(Ita $LATRAD $DISTANCIA_ANGULAR)
NI=$(Ni $RADPOLAR $EXC2 $LATRAD)
DSETA=$(Zeta $EXC2 $XI $LATRAD)
A1=$(FunctionA1 $LATRAD)
A2=$(FunctionA2 $A1 $LATRAD)
J2=$(FunctionJ2 $LATRAD $A1)
J4=$(FunctionJ4 $J2 $A2)
J6=$(FunctionJ6 $J4 $A2 $LATRAD)
ALPHA=$(Alpha $EXC2)
BETA=$(Beta $ALPHA)
GAMMA=$(Gamma $ALPHA)
B=$(FunctionB $RADPOLAR $LATRAD $ALPHA $J2 $BETA $J4 $GAMMA $J6)
X=$(CoordX $XI $NI $DSETA)
Y=$(CoordY $ETA $NI $DSETA $B $ADDVALUE)

# Parámetros correctos
if [ $DEBUG -eq 1 ]; then
  cat >&2 <<!
  Datum: $DATUMSELECT
  Elipsoide: $ELIPSOIDE
  Huso: $HUSO
  Coord: $LATITUD, $LONGITUD
  Latitud: $LATRAD rad
  Longitud: $LONRAD rad
  PI: $PI
  EXC1: $EXC1
  EXC2: $EXC2
  RADIO POLAR: $RADPOLAR
  APLANAMIENTO: $APLANAMIENTO
  ADD: $ADDVALUE
  MERIDIANO CENTRAL: $MERIDIANO_CENTRAL
  DISTANCIA ANGULAR: $DISTANCIA_ANGULAR
  A: $A
  XI: $XI
  ETA: $ETA
  NI: $NI
  DSETA: $DSETA
  A1: $A1
  A2: $A2
  J2: $J2
  J4: $J4
  J6: $J6
  ALPHA: $ALPHA
  BETA: $BETA
  GAMMA: $GAMMA
  B: $B
  X: $X
  Y: $Y
!
elif [ $TECH -eq 0 ]; then
  echo -e "Datum: $DATUMSELECT\nElipsoide: $ELIPSOIDE\nHuso: $HUSO\nCoord X: $X\nCoord Y: $Y" >&2
else
  INTX=$(echo $X | cut -d "." -f 1)
  INTY=$(echo $Y | cut -d "." -f 1)
  echo "$INTX $INTY"
fi

exit 0
# vim: nu: sw=2: ts=2
