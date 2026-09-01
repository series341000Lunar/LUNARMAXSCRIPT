# Lunar Transform Assistant

[한국어](README.md) · [Català](README.ca.md)

Eina de producció MAXScript per a Autodesk 3ds Max 2026. Copia o instancia Transform Channels, Full Transform i Base Objects compatibles entre un Source i diversos Targets definits explícitament, i gestiona els Transform Locks i l'estat Hidden a nivell de Node de la Selection actual.

Prioritza el comportament previsible i la conservació de les dades existents de la Scene. Les estructures de Controller no compatibles s'ometen i se n'explica el motiu al Listener; no es converteixen automàticament.

## Fitxers

```text
src/LunarTransformAssistant.ms
macros/LunarTransformAssistant.mcr
README.md
README.ca.md
```

## Instal·lació i execució

Estructura recomanada:

```text
<3ds Max user scripts>\LunarTransformAssistant\src\LunarTransformAssistant.ms
<3ds Max user scripts>\LunarTransformAssistant\macros\LunarTransformAssistant.mcr
```

1. Copieu `src` i `macros` amb l'estructura anterior.
2. A 3ds Max, obriu **Scripting > Run Script** i executeu `macros\LunarTransformAssistant.mcr`.
3. A **Customize > Customize User Interface**, afegiu l'Action `Lunar Transform Assistant` de la Category `Lunar Tools` a una Toolbar, Menu, Quad Menu o Keyboard Shortcut.

Metadata del MacroScript:

```text
Category: Lunar Tools
Internal name: LunarTransformAssistant
Tooltip: Lunar Transform Assistant
```

El Launcher busca primer `..\src\LunarTransformAssistant.ms` respecte a la seva ubicació i després comprova el directori recomanat de User Scripts. Si el Rollout ja és obert, enfoca el Dialog existent sense duplicar-lo ni reinicialitzar Source/Targets. Per a una execució puntual sense registrar l'Action, podeu executar directament `src/LunarTransformAssistant.ms`.

## Workflow de Source / Target

### Manual

1. Seleccioneu un únic Scene Node i premeu `Set Source`.
2. Seleccioneu un o més Target Nodes i premeu `Set Targets`.
3. Executeu l'operació Copy o Instance desitjada.

Si el Source forma part de la captura de Targets, s'exclou automàticament. Abans de cada operació es tornen a validar els Nodes desats; els Targets eliminats o invàlids es retiren de manera segura i un Source eliminat es neteja. `Clear Targets` només buida la llista de Manual Targets.

Transform Lock i `Unhide Selected Nodes` fan servir la Selection actual de 3ds Max en el moment de prémer el botó, no els Source/Targets desats.

### First Selected = Source / Last Selected = Source

1. Premeu `Start / Reset Ordered Selection`.
2. Combineu seleccions individuals i múltiples en l'ordre desitjat.
3. En mode First, el primer Node del Flattened Batch Order és el Source i la resta són Targets.
4. En mode Last, l'últim Node és el Source i tots els anteriors són Targets.

Manual State i Ordered Selection Batch History es desen per separat. Canviar de Mode no n'esborra cap. First i Last comparteixen el mateix Batch History i el reinterpreten immediatament.

## Regles d'Ordered Selection

- Una Action que afegeix un Node crea un Single Selection Batch i conserva l'ordre exacte de l'Action.
- Una Action que afegeix diversos Nodes crea un Multiple Selection Batch. S'admeten Rectangle Selection i Select By Name multi-selection.
- Els Batches s'aplanen segons l'ordre de creació.
- Dins d'un Multiple Selection Batch no hi ha un Viewport Click Order significatiu; s'utilitza un ordre determinista per Node Handle ascendent amb Name Fallback.
- Es poden combinar Batches Single i Multiple, per exemple single A → multiple B-Z → single Final.
- Si existeix algun Multiple Batch, la UI amaga els noms individuals i l'ordre intern i mostra només un resum `Multiple Selection` o `Mixed / Multiple Selection` i el nombre d'Objects.
- Deselect elimina el Node de l'ordre. Un Multiple Batch continua essent Multiple encara que només hi quedi un Node.
- Tornar a seleccionar un Node crea un nou últim Single Batch; diversos Nodes creen un nou últim Multiple Batch.
- Un Node no pot aparèixer en més d'un Batch i calen almenys dos Nodes vàlids.
- Abans d'una nova sessió ordenada, feu servir `Start / Reset Ordered Selection`.

El Callback compara el snapshot anterior de Selection amb la Selection vàlida actual. L'ordre de l'AnimHandle Array de `NodeEventCallback` i l'ordre de la col·lecció `selection` de 3ds Max no es consideren Click Order de l'usuari. Els Nodes eliminats es netegen durant el Callback, l'UI Refresh i l'Operation Validation.

## Copy i Instance

Copy escriu el valor avaluat actual o un Base Object independent:

- Selected Transform Channel Copy: copia només els valors del Frame actual.
- Full Transform Copy: assigna la Source World Transform Matrix.
- Base Object Copy: assigna una còpia independent del Source Base Object.

Instance comparteix Controllers o referències de Base Object:

- Selected-channel Instance: comparteix només el Component Controller marcat.
- Full Transform Instance: comparteix tot el Transform Controller.
- Base Object Instance: comparteix el Source Base Object.

La relació d'Instance és bidireccional; modificar qualsevol costat pot afectar tots els Nodes que comparteixen la referència. No es converteixen Controllers per forçar la compatibilitat.

## Comportament dels Transform Channels

La matriu controla X/Y/Z de Position, Rotation i Scale. Els checkboxes de Transform Copy i de Transform Lock són independents.

### Current-value Copy

Quan hi ha Component Tracks independents, l'eina llegeix el valor actual del Source Component Controller i l'escriu al mateix Component del Target a `currentTime`.

- Position: `Position_XYZ`
- Rotation: `Euler_XYZ`
- Scale: `ScaleXYZ`

Si Source i Target tenen un Axis Order diferent a `Euler_XYZ`, l'operació s'omet perquè els mateixos angles X/Y/Z no tenen la mateixa interpretació.

El `Bezier_Scale` estàndard no té Subcontrollers X/Y/Z independents. Només per a `Copy Selected Channels`, una parella Source/Target `Bezier_Scale` és compatible mitjançant un Current Scale Value compost: els Components marcats provenen del Source i els no marcats conserven els valors avaluats del Target. No es canvia el Controller ni es copien Keys, però en un Frame animat 3ds Max pot actualitzar o crear una Composite Scale Key segons l'Animate State actual.

### Selected-channel Instance

Només està disponible quan Source i Target ofereixen un Component Controller independent, compatible i writable:

- `Position_XYZ`
- `Euler_XYZ` amb el mateix Axis Order
- `ScaleXYZ`

S'inspeccionen el Category Controller i el Component SubAnim reals, i el Source Component Controller s'assigna només al Component marcat del Target. Els Components no marcats es conserven. No s'admet Instance d'un Axis individual de `Bezier_Scale`.

### Exemples de Controllers no compatibles

- Quaternion / TCB Rotation
- Rotation List, Position List i Scale List
- LookAt / Path Constraint
- Script Controller
- CAT / Biped Controller
- Plugin-specific Controller
- Component SubAnim absent o no writable
- Euler Axis Order diferent

Els casos no compatibles s'ometen amb informació `[LTA][WARN]` o `[LTA][ERROR]`. L'eina no canvia Controller Types, no elimina Keys i no crea Constraints ni Wire Parameters.

## Full Transform

`Copy Full Transform` assigna el Source World Transform a cada Target sense modificar-ne el Parent. Després compara el Target World Matrix amb el del Source i no compta com a èxit cap resultat rebutjat o parcial.

`Instance Full Transform` assigna tot el Source Transform Controller al Target. Si Source i Target tenen Parents diferents, s'avisa que un mateix Local Controller pot produir World Transforms diferents, però no es modifica el Parenting.

Transform Locks, Constraints, Special Rigs o Controllers no compatibles poden impedir l'assignació o provocar un resultat de Verification Rejected.

## Base Object

L'abast inclou Geometry Base Objects ordinaris, Primitives i Geometry habitual compatible amb Editable Poly.

```maxscript
-- Copy Base Object
target.baseObject = copy source.baseObject

-- Instance Base Object
target.baseObject = source.baseObject
```

Només s'assigna `baseObject`. No es clona el Node complet, no es copia el Source Modifier Stack, no es fa Stack Collapse, no es canvia el Parent, no es reanomena el Target i no es copia el Material. Si 3ds Max accepta la combinació, els Modifiers existents del Target es conserven sobre el Base Object substituït.

No són compatibles els Non-Geometry Base Objects, XRef Base Objects, Group Heads ni les combinacions Object/Modifier Stack rebutjades per 3ds Max.

## Transform Lock

Les operacions Lock fan servir la Selection actual i una matriu de Lock Checkboxes independent. L'ordre dels bits de Transform Lock de 3ds Max és:

```text
1 Position X
2 Position Y
3 Position Z
4 Rotation X
5 Rotation Y
6 Rotation Z
7 Scale X
8 Scale Y
9 Scale Z
```

`Lock Checked` i `Unlock Checked` llegeixen el BitArray existent, canvien només els bits marcats i verifiquen que la resta es conservin. `Lock All` i `Unlock All` estableixen i verifiquen els nou bits. No canvien Controller Types ni Animation Keys.

## Visibility

`Unhide Selected Nodes` només estableix aquest valor sobre la Selection actual:

```maxscript
node.isNodeHidden = false
```

No fa Unhide del Layer. Si el Layer continua ocult, el Listener mostra un Warning. Els altres Objects del mateix Layer no es modifiquen.

## Undo, diagnòstic i abast compatible

- Cada botó que modifica la Scene executa el Batch dins d'un únic Named Undo Block.
- Diversos Targets es processen en Batch i la fallada d'un Target no atura la resta.
- `redrawViews()` s'executa com a màxim una vegada després del Batch i només si s'ha verificat algun canvi.
- L'UI Status mostra el resultat breu; el Listener mostra motius per Node i Batch Summaries amb `[LTA][INFO]`, `[LTA][WARN]` i `[LTA][ERROR]`.
- L'abast principal inclou Geometry Nodes ordinaris, Standard PRS, Position XYZ, Euler XYZ, Scale XYZ, Current-value Copy de Bezier Scale, Primitive/Editable Poly-compatible Base Objects i múltiples Targets.
- Special Rigs, XRefs, Group Heads, Non-Geometry Base Objects i Plugin-specific Controllers queden fora de l'abast.

## Limitacions conegudes

- Els Channels seleccionats són Components en Controller Space; no es reinterpreten entre Controller Types o Euler Axis Orders diferents.
- Current-value Assignment segueix el Frame actual i l'Animate Mode de 3ds Max; en Controllers animats pot actualitzar o crear Keys.
- Full Transform Instance comparteix la sortida del Local Controller, per tant Parents diferents poden produir World Transforms diferents.
- La compatibilitat final de la substitució de Base Object la decideix 3ds Max.
- Node-level Unhide no pot resoldre la invisibilitat causada per Layer, Category o Frozen display.
- És recomanable comprovar a la build de 3ds Max de destinació l'Undo real de Controller/Base Object Assignment i la compatibilitat amb Production Rigs especials.

+## Checklist manual de Runtime Tests

### Source / Target

- [ ] Definiu un Source vàlid.
- [ ] Definiu un Target i diversos Targets.
- [ ] Elimineu un Target desat i executeu una operació.
- [ ] Incloeu accidentalment el Source a la captura de Targets i confirmeu que s'exclou.
- [ ] Canvieu a First Selected i confirmeu que es conserven Manual Source/Targets.
- [ ] Torneu a Manual i confirmeu que l'estat Manual original torna a ser actiu.

### Ordered Selection

- [ ] Trieu First Selected, feu Reset i seleccioneu A, `Ctrl+B`, `Ctrl+C`.
- [ ] Confirmeu que Active Source és A i Active Targets són B/C.
- [ ] Canvieu només a Last Selected i confirmeu que Source passa a C i Targets a A/B.
- [ ] Feu Deselect de B i confirmeu A/C; torneu a seleccionar B i confirmeu A/C/B.
- [ ] Després d'un Reset, seleccioneu només A i confirmeu que les operacions Source/Target queden bloquejades.
- [ ] Feu Rectangle-select d'almenys 20 Nodes i confirmeu un Multiple Selection Summary vàlid i un Source estable.
- [ ] Repetiu la mateixa multi-selection amb un ordre aparent diferent i confirmeu el mateix Source.
- [ ] Comproveu Single→Multiple, Multiple→Single i Single→Multiple→Single en modes First i Last.
- [ ] Feu Deselect de diversos Nodes d'un Multiple Batch i confirmeu que només s'eliminen aquests Nodes.
- [ ] Feu Deselect i Reselect d'un Node i confirmeu que esdevé un nou últim Single Batch.
- [ ] Confirmeu que els noms individuals i l'ordre intern s'amaguen quan existeix un Multiple Batch.
- [ ] Elimineu un Ordered Node desat i confirmeu que es retira sense excepcions.
- [ ] Tanqueu i torneu a obrir el Rollout i confirmeu que cada Selection Event es registra una sola vegada.

### Transform Copy / Instance

- [ ] Copieu només Position X, Position X/Z, Rotation Y i Non-uniform Scale X.
- [ ] Confirmeu que els Channels no marcats es conserven.
- [ ] Comproveu Copy en un Animation Frame diferent de zero.
- [ ] Feu Instance només de Position X amb Position XYZ Controllers i confirmeu la referència compartida.
- [ ] Modifiqueu el Target i confirmeu la relació d'Instance bidireccional amb el Source.
- [ ] Confirmeu que una operació no compatible no modifica el Target.

### Full Transform / Base Object

- [ ] Comproveu Full Transform Copy sense Parents, amb el mateix Parent i amb Parents diferents.
- [ ] Comproveu Full Transform Instance amb el mateix Parent i el Warning amb Parents diferents.
- [ ] Executeu Base Object Copy/Instance d'un Sphere Source a un Box Target.
- [ ] Confirmeu la conservació de Target Transform, Material i Modifier Stack.
- [ ] Confirmeu que Copy crea Geometry independent i Instance comparteix el Base Object.
- [ ] Repetiu-ho amb diversos Targets.

### Visibility / Lock / Undo

- [ ] Feu Unhide d'un Node ocult i confirmeu el Warning quan el Layer continua ocult.
- [ ] Confirmeu que els altres Objects del mateix Layer no canvien.
- [ ] Apliqueu Position X Lock, afegiu Rotation Y Lock i després feu Position X Unlock, conservant la resta de Flags.
- [ ] Comproveu Lock All / Unlock All i Multiple Selection.
- [ ] Confirmeu que cada botó es pot restaurar amb un sol Undo dins de l'abast compatible.

## Abast de la revisió estàtica

S'han revisat els punts següents:

- separació entre Manual Capture State i Ordered State controlat per Callback;
- absència d'ús de l'ordre de `selection[]` com a Click Order;
- resolver First/Last compartit sobre Single/Multiple Batches aplanats;
- diff entre Previous/Current Selection Snapshot sense confiar en Callback Handle Order;
- ordre determinista per Node Handle dins dels Multiple Batches;
- prevenció de duplicats, eliminació amb Deselect, neteja d'Empty Batches i append amb Reselect;
- Rollout-local State i una única Global Rollout Reference intencionada;
- neteja de Stale Nodes amb `isValidNode` a Manual i Ordered State;
- registre, alliberament i prevenció de duplicats de `NodeEventCallback`;
- un Undo Context per cada Scene-changing Button Path;
- aïllament d'excepcions per Target i Diagnostic Summaries;
- conservació dels Channels i Lock States no marcats;
- absència de Controller Conversion, Stack Collapse, `instanceReplace`, Constraints i Wire Parameters;
- assignació exclusiva de Base Object amb conservació del Target Modifier Stack;
- un màxim d'un Redraw per Batch modificat;
- registre no duplicat del MacroScript i comportament de Dialog Reopen.

## Estat de verificació

Amb Autodesk 3ds Max 2026.3.3 Batch s'han verificat automàticament Main Rollout, MacroScript Launch/Reopen, Position X Copy/Instance, còpia parcial de `Bezier_Scale`, Transform Lock, Base Object Copy/Instance, conservació dels Target Modifiers, Full Transform Copy/Instance, els tres Selection Modes, Mixed Single/Multiple Batches, Deselect/Reselect, neteja de Nodes eliminats i Callback Release/Reopen.

El Batch Harness va passar AnimHandle Arrays reals als Handlers de `NodeEventCallback`. Els gestos reals de Viewport `Ctrl+Click`, Rectangle Selection i Select By Name, la presentació de la UI, One-step Undo, Animation en Frames no zero, Layer-hidden Warning, Special Rigs i un ventall més ampli de Production Modifier Stacks s'han de verificar manualment a la UI normal de 3ds Max.

Els errors `nToolFloat` i `vexus_startup.ms` del Batch Log provenien de Third-party Startup Scripts preexistents i no es van atribuir a Lunar Transform Assistant.

## Llicència

Aquesta eina es distribueix sota la GNU General Public License v3.0. Consulteu [../LICENSE](../LICENSE) per obtenir-ne els detalls.
