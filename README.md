# L4D2 Boomer Tank Punch v5.4

## Descripcion
Plugin para L4D2. Le da al Boomer 2 habilidades:
1.  **MOUSE2**: Golpe en area igual al del Tank. Empuja y daña a los survivors.
2.  **VOMITO**: Cada vomito sube de nivel. Al nivel 1-4 spawnea horda de infectados.

## Requisitos
- SourceMod 1.11 o superior
- Metamod 1.12 o superior
- Left 4 Dead 2
- left4dhooks.inc

## Instalacion
1. Descarga `left4dhooks.inc` y metelo en `addons/sourcemod/scripting/include/`
2. Compila `boomer_tank_punch.sp` con spcomp
3. Mete `boomer_tank_punch.smx` en `addons/sourcemod/plugins/`
4. Reinicia el servidor. El cfg se crea solo en `cfg/sourcemod/boomer_berserker.cfg`

## Cvars
Archivo: `cfg/sourcemod/boomer_berserker.cfg`

**Daño y Golpe**
sm_boomer_punch_damage "5"
sm_boomer_punch_force "1200"
sm_boomer_punch_upforce "400"
sm_boomer_punch_delay "2.5"

**Horda por Vomito**
sm_boomer_horde_1 "13"
sm_boomer_horde_2 "23"
sm_boomer_horde_3 "43"
sm_boomer_horde_4 "53"

## Datos Tecnicos
- Rango de golpe: 120.0 unidades
- Angulo de golpe: 0.7 cono
- Maximo nivel de vomito: 4
- El nivel se resetea al morir o desconectarse

## Autor
Shadow L4D2
