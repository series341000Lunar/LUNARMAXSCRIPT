# Lunar Material ID Normalizer MK2

[한국어](README.md) · [Català](README.ca.md)

Utilitat MAXScript per a 3ds Max que preprocessa els `USD Preview Surface` dels objectes importats des de Cinema 4D o USD com a `VRayMtl` simples, i normalitza tant l'ordre divergent dels Material ID de Multi/Sub-Object com els Material ID de les cares d'Editable Poly a partir d'un únic Master.

## Execució

1. A 3ds Max, obriu `Scripting > Run Script...`.
2. Executeu [`src/LunarMaterialIDNormalizer.ms`](src/LunarMaterialIDNormalizer.ms).

La interfície s'obre i funciona amb aquest únic fitxer de script.

## Seqüència d'ús

1. A `PREPROCESS`, configureu la conversió USD, els nous overrides de VRayMtl i la sincronització dels noms dels slots Multi/Sub.
2. Seleccioneu un objecte resultant d'Attach com a referència i premeu `Set Master`.
3. Seleccioneu la resta d'objectes resultants d'Attach i premeu `Add Selected Targets`.
4. Premeu `Analyze` per revisar l'estat de conversió previst, la Canonical Material Table i la Target Remap Preview.
5. Els materials nous es mostren com a `PENDING APPEND : <Object>`.
6. Si no hi ha conflictes de nom/class/color ni de nom/ID del Master, i la preview és correcta, premeu `Normalize / Apply`.

`Convert Materials Only` és independent del registre de Master/Targets. En prémer el botó, només llegeix la scene selection actual i hi aplica la conversió USD → VRayMtl i, opcionalment, la sincronització dels noms dels slots. No fa canonical append, no modifica els Material ID de les cares, no normalitza Targets ni assigna el material del Master; així, el resultat de la conversió es pot inspeccionar abans a Slate Material Editor. Si no hi ha cap objecte seleccionat, no modifica la scene i mostra `ERROR: Select one or more objects to convert.`.

L'Apply complet, incloses la conversió USD, l'append, el remap dels face ID i l'assignació del material del Master, queda agrupat en una única operació Undo anomenada `Convert USD and Normalize Material IDs`.

## GLOBAL A-Z REINDEX

`Global A-Z Reindex...` de MK2 és una operació basada en la selecció i completament independent de la normalització existent de Master/Targets. Obriu-la, executeu `Analyze Selection` sobre la selecció actual, reviseu el registre global i el remap per objecte, i després executeu `Apply Reindex`.

- Només llegeix els nodes seleccionats compatibles amb Multi/Sub + Editable Poly; no necessita ni modifica els Master/Targets registrats.
- Reuneix els noms de tots els submaterials no buits en un únic registre global sense distingir majúscules/minúscules, els ordena amb `.NET OrdinalIgnoreCase` i assigna Global ID `1..N`. Es conserva la capitalització del nom de material existent.
- La comparació utilitza únicament el string complet exacte. `Concrete`, `Concrete.001` i `Concrete_01` són noms diferents; no s'eliminen sufixos ni s'apliquen coincidències fuzzy o parcials.
- Només reordena els contenidors Multi/Sub i les referències de submaterial existents. No crea slots per a Global ID absents, ni crea, clona o converteix materials.
- Els slots no buits de cada Multi/Sub s'ordenen segons el Global ID corresponent, i `materialIDList` i el nom del slot se sincronitzen conjuntament. Els slots buits segurs es conserven; un slot buit que col·lideixi amb un Global ID nou o que sigui utilitzat per una face bloqueja l'operació.
- Els face ID es remapen una sola vegada a partir dels Face BitArray snapshot originals i d'un lookup numèric per objecte, de manera que els intercanvis d'ID no depenen d'estats intermedis.
- Una diferència de raw material class o de diffuse comparable dins d'un mateix nom sense distingir majúscules/minúscules bloqueja tota l'operació. També la bloquegen els noms duplicats només per capitalització dins d'un Multi/Sub, els Material ID duplicats i els face ID no definits.
- Si diversos nodes comparteixen una mateixa referència Multi/Sub, aquesta només es reordena una vegada quan tots els usuaris que es poden remapejar amb seguretat estan seleccionats. Un usuari Editable Poly absent es classifica com `REQUIRED / NOT SELECTED`, i un usuari que no es pot remapejar com `REQUIRED / UNSUPPORTED GEOMETRY`; tots dos bloquegen Apply.
- `Select Required Objects` afegeix a la selection existent les referències reals de Scene Node que Analyze ha desat i executa immediatament un nou Analyze. No torna a cercar nodes pel nom; també inclou nodes ocults sense modificar els estats Hidden/Frozen, la Layer, la hierarchy ni les dades de la scene.
- Si una Geometry no compatible és un usuari obligatori fora de la selection, el botó també intenta afegir-la, però el nou Analyze manté el conflicte `REQUIRED / UNSUPPORTED GEOMETRY` i el bloqueig d'Apply. No es fa Convert/Collapse automàtic ni s'evita cap protecció.
- Els nodes amb material únic, sense material o que no són Editable Poly s'ometen; no es converteixen automàticament ni se'ls crea cap contenidor.
- Just abans d'Apply es torna a executar Analyze sobre la selecció i la scene actuals, i tots els canvis dels arrays de material i dels face ID queden en una única operació Undo anomenada `Global A-Z Material Reindex`.
- No es modifiquen topology, transform, pivot, object name, UV, smoothing group, normal, modifier stack ni els noms, classes o propietats dels submaterials existents.

## Preprocessament USD → VRayMtl

- `Convert USD Preview Surface to VRayMtl` està activat per defecte; si es desactiva, només s'executa la normalització existent dels Material ID.
- El contenidor Multi/Sub i els Material ID es conserven, i només se substitueixen les referències de submaterial `MaxUsdPreviewSurface`.
- El nou VRayMtl només copia el nom original i el `diffuseColor` constant.
- No es crea cap texture network: només s'utilitza el fallback color, i la Table ho indica com a `TEXTURE IGNORED`.
- No es converteixen metallic, roughness, opacity, emission, normal, displacement ni altres propietats.
- Una mateixa referència original de material USD reutilitza una sola referència VRayMtl mitjançant la conversion cache.
- Els VRayMtl existents i els materials no compatibles no es modifiquen.
- `Override Glossiness` és un valor de glossiness de V-Ray entre 0.0 i 1.0, i `Override Reflection` és un color RGB. Tots dos només s'apliquen als VRayMtl creats durant l'Apply actual.
- Si un Override està desactivat, no es calcula cap valor a partir de roughness/metallic d'USD i es conserva el valor per defecte del VRayMtl.
- Si es detecta el mateix nom exacte amb diffuse colors diferents, un conflicte `SAME NAME / DIFFERENT DIFFUSE` bloqueja l'Apply.
- Si V-Ray no està disponible o no es poden utilitzar les propietats verificades de VRayMtl, no es modifica la scene i es mostra un error.
- `Analyze` només calcula el pla: no crea cap VRayMtl ni substitueix referències de material.

## Validació de la classe del material

- Es manté el principi existent segons el qual el Material Name exacte és la canonical identity.
- Raw Class és la classe real de la scene actual; Effective Class és la classe prevista després del preprocessament actiu.
- Amb la conversió activada, l'Effective Class de `MaxUsdPreviewSurface` és `VRayMtl`.
- Un USD i un VRayMtl amb el mateix nom són un MATCH vàlid si l'effective class i el diffuse coincideixen.
- Si el nom coincideix però l'effective class és diferent, un `CLASS CONFLICT` bloqueja Analyze i Apply.
- Si el nom i l'effective class coincideixen però els diffuse comparables són diferents, un `COLOR CONFLICT` bloqueja l'operació.
- La canonical key no es canvia a `Name + Class`; per tant, els noms duplicats no se separen silenciosament en materials canònics diferents.

## Sincronització dels noms dels slots Multi/Sub

- `Sync Multi/Sub Slot Names` està activat per defecte.
- En el moment de l'operació, `materialList[i].name` es copia a `names[i]` del mateix slot.
- El face ID real es conserva separadament a `materialIDList[i]`; no es pressuposa que l'índex del slot coincideixi amb el Material ID.
- Els slots de submaterial buits no es modifiquen, i no s'instal·len rename callbacks ni watchers permanents.
- Els canvis de scene de `Convert Materials Only` i `Normalize / Apply` s'inclouen en la mateixa unitat Undo.

## Exportació d'informes

- `Export Report...` obre el quadre de diàleg Save File estàndard i desa un `.txt` en UTF-8.
- Els informes nous inclouen `Report Format Version: 1`.
- Després d'Analyze, l'informe recull l'estat previst de conversion/effective class/append/remap; després d'un canvi de scene, recull l'estat final real tornat a llegir.
- L'informe inclou configuració, Master/Targets, summary, canonical table, remap per Target, conversion, appended material i conflict/warning, però no fa cap dump per face.
- `Auto Export After Operation` està desactivat per defecte. Si s'activa, desa l'informe després que un Convert Only o Normalize/Apply correcte hagi actualitzat la UI.
- Per a una scene desada s'utilitza automàticament la seva carpeta; per a una scene no desada, la carpeta d'exportació de 3ds Max.
- El nom per defecte segueix el format `<SceneName>_MaterialNormalize_<Operation>_<YYYYMMDD_HHMMSS>.txt`.
- Els informes d'Analyze/Apply de Global A-Z registren l'operation com a `GLOBAL A-Z ANALYZE` o `GLOBAL A-Z REINDEX` i afegeixen les seccions opcionals `[GLOBAL A-Z REINDEX]` i `[PER OBJECT A-Z REMAP]`.

## Càrrega d'informes

- `Load Report...` permet seleccionar un informe `.txt` UTF-8 amb el quadre de diàleg Open File estàndard. Cancel no modifica ni l'estat ni la scene.
- Només s'accepten fitxers on la primera línia significativa sigui exactament `Lunar Material ID Normalizer Report`.
- Es llegeixen tant els informes amb `Report Format Version: 1` com els informes legacy sense aquesta línia si les seccions existents es poden reconèixer; aquests darrers s'interpreten com a format 1.
- El parser admet salts de línia CRLF/LF, capçaleres `[SECTION]` explícites i taules separades per tabuladors. Les seccions opcionals absents, les files truncades i els enters no vàlids es conserven com a text sempre que sigui possible i es mostren com a `PARSER WARNING`.
- El contingut carregat es consulta en un visor modeless separat, `LOADED REPORT — READ ONLY`, amb les pestanyes Summary, Canonical Materials, Target Remap, Conversions, Appended i Conflicts / Warnings. Quan hi ha les seccions opcionals de MK2, també es mostren a les pestanyes Global A-Z i Per-Object A-Z; els informes MK1 existents es continuen llegint amb aquestes pestanyes opcionals buides.
- A la pestanya Target Remap es pot escollir un Target desat a l'informe; també hi ha `Open Another Report...` i `Close`.
- El snapshot carregat només conserva strings i arrays de valors. No cerca ni referencia scene nodes, i no afecta la selection actual, Master/Targets, Analyze, `Convert Materials Only` ni `Normalize / Apply`.

En l'entorn d'instal·lació actual, les propietats verificades i utilitzades són `diffuseColor` i `diffuseColor_map` d'USD, i `Diffuse`, `Reflection`, `reflection_glossiness` i `brdf_useRoughness` de VRayMtl. Just abans de l'Apply, aquestes classes i propietats es tornen a validar.

## Principis de processament

- El Master ha de tenir un material Multi/Sub-Object.
- La comparació de noms és una comparació exacta de strings i distingeix entre majúscules i minúscules.
- No s'apliquen correccions automàtiques com eliminar `.001`, `_001` o sufixos numèrics, ni coincidències fuzzy o parcials.
- No es pressuposa que el slot de l'array Multi/Sub coincideixi amb el Material ID.
- Cada fila llegeix conjuntament `materialList[slot]` i `materialIDList[slot]`.
- Els ID existents del Master no es reordenen ni es modifiquen.
- Un ID nou és el número següent al màxim entre els ID actuals del Master i els reservats durant Analyze.
- Un material nou afegeix al darrer slot del Master la mateixa referència de submaterial que el Target ha utilitzat realment.
- Si un Target utilitza el mateix nom en diversos ID, tots es fusionen en un únic Master ID.
- Si el Master conté el mateix nom en ID diferents, o el mateix ID en diversos slots, l'Apply queda bloquejat.
- Els Targets sense material i els Targets que no són Editable Poly s'ometen i la UI en mostra l'estat.
- Per als Targets compatibles, les cares es agrupen primer per lookup numèric d'ID i després `polyop.setFaceMatID` aplica cada ID a un Face BitArray.
- Després del remap de les cares, el Target rep la mateixa referència de material Multi/Sub que el Master.

## Elements que no es modifiquen

Aquesta eina no modifica intencionadament els elements següents:

- Topology de Vertex, Edge o Face
- Object transform, pivot o object name
- UV, smoothing group o normal
- Modifier stack
- Els noms i les propietats dels VRayMtl existents o dels materials que no són objecte de conversió
- Els Material ID existents del Master

## Abast i limitacions

- Només s'editen les cares dels nodes amb un base object de classe `Editable_Poly`. No es fa cap conversió automàtica ni stack collapse.
- El Master només admet material Multi/Sub-Object.
- Els Targets admeten tant material Multi/Sub-Object com material únic.
- Si un Multi/Sub d'un Target conté el mateix Material ID duplicat en diversos slots, el significat és ambigu i el Target es tracta com un error.
- Si una cara del Target utilitza un ID que no està definit al Multi/Sub, el Target es tracta com un error.
- Com que la scene pot haver canviat després d'Analyze, just abans d'Apply s'executa automàticament un nou Analyze.
- És recomanable verificar també en l'entorn de producció el comportament de la UI, l'Undo d'un sol pas i les referències de materials específiques del renderer/plugin.

## Validació automatitzada

S'han executat `tests/LunarMaterialIDNormalizer_smoke.ms` amb Autodesk 3ds Max 2026.3.3 Batch i han passat 189 comprovacions. Es conserva tota la regressió MK1, incloses la conversió USD i la independència del report loader, i es verifiquen per a Global A-Z l'ordenació determinista sense distingir majúscules/minúscules, la clau de nom exacta, els ID existents diferents i els subconjunts, els intercanvis d'ID, els contenidors Multi/Sub compartits i separats, l'omissió de material únic, el bloqueig d'ID duplicats, face ID no definits, ús de slots buits, noms duplicats i conflictes de class/color, la conservació de slots buits segurs i de referències de classes de material mixtes, el fresh Analyze, la independència entre selecció actual i Master/Targets, l'Undo d'un sol pas i l'exportació/càrrega de les seccions opcionals MK2. També es verifiquen l'additive selection i la conservació d'estat d'usuaris externs ocults, congelats, visibles i múltiples, l'ús de la referència exacta del node, el nou Analyze automàtic, la permanència del bloqueig per Geometry no compatible i l'omissió segura d'un node cached eliminat.

Un probe de la GUI de 3ds Max ha confirmat l'obertura real del quadre de diàleg Save File i del quadre Open File de Load Report, que Cancel de Load no executa cap acció, i la visualització del visor modeless de només lectura. El probe MK2 també ha confirmat la creació real de les pestanyes Global Registry, Per-Object Preview i Conflicts / Skipped de la finestra Global A-Z, i de les pestanyes Global A-Z i Per-Object A-Z del visor d'informes. El botó `Select Required Objects` només queda habilitat quan hi ha un usuari extern; després d'un clic real, conserva la selection i l'estat Hidden existents, afegeix el node obligatori i habilita Apply. La funció de generació de l'informe i el contingut UTF-8 s'han verificat amb Batch.

MK2 manté el comportament congelat de MK1 i hi afegeix el workflow independent Global A-Z.

## Procediment de prova breu

- Executeu Analyze/Apply amb Targets Multi/Sub A/B/C que només difereixin en l'ordre i confirmeu que cada face utilitza l'ID del Master.
- Quan D només existeixi al Target, confirmeu que s'afegeix una sola vegada com a `max(materialIDList) + 1` del Master.
- Si D es repeteix en diversos Targets, confirmeu que comparteixen el mateix ID i la mateixa referència de submaterial del Master.
- Si els ID del Master són 1, 4 i 8, confirmeu que el nou D rep l'ID 9.
- Si el Master conté el nom A en dos ID, confirmeu que es mostra `DUPLICATE NAME` i que l'Apply queda bloquejat.
- Confirmeu que un Target sense material s'omet mentre la resta es processen correctament.

## License

This tool is licensed under the GNU General Public License v3.0. See [../LICENSE](../LICENSE).
