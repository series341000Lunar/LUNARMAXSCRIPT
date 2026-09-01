# Lunar Geometry Preprocessor MK1

[한국어](README.md) · [Català](README.ca.md)

`LunarGeometryPreprocessor_MK1.ms` és una eina MAXScript independent per a 3ds Max 2026. Classifica Geometry col·locada manualment i importada des d'un DCC extern mitjançant dades Mesh estrictes; després permet que l'usuari verifiqui el significat de cada Group, introdueixi el Family Name i executi de manera segura el Rename o, opcionalment, la normalització de les relacions d'Instance.

## Execució

Executeu el fitxer següent des de **Scripting > Run Script** a 3ds Max:

```text
src\LunarGeometryPreprocessor_MK1.ms
```

## Workflow recomanat

1. Seleccioneu la Scene Geometry que voleu classificar. Camera, Light, Helper, Point, tyFlow i Particle System s'exclouen automàticament.
2. Premeu `ANALYZE SELECTED GEOMETRY`. Analyze no modifica la Scene i només conserva un snapshot de Node Handles.
3. Seleccioneu una Row de la taula i reviseu el model al Viewport amb `SELECT GROUP` o `FRAME GROUP`.
4. Introduïu manualment el Family Name de cada Group a la cel·la `Group Name (edit)`. Un nom buit, duplicat o invàlid, o una col·lisió del nom final amb un Scene Node extern, bloqueja Apply.
5. Feu servir `RENAME GROUPS` per canviar només els noms, `MAKE INSTANCES` per normalitzar només les relacions d'Instance, o `APPLY ALL` per aplicar totes dues operacions.

El format de Rename comença a `<GroupName>_001` per a cada Group. La numeració s'assigna primer als Nodes que tenien el trailing number original més petit.

## Criteri de Geometry

- Fast Bucket: nombre de vèrtexs i de cares.
- Strict Hash: SHA-256 de les posicions locals quantificades dels vèrtexs i dels índexs ordenats de cada cara.
- Final Verify: comparació de totes les posicions locals amb una tolerància de `0.0001` scene units i comparació exacta dels índexs dels vèrtexs de cada cara.

SHA-256 accelera la cerca prioritària dins del Candidate Bucket. Si un error de precisió simple al límit de quantificació produeix hashes diferents, la comparació estricta final dins del mateix Verts/Faces Bucket decideix el resultat. Per tant, una col·lisió o discrepància de hash per si sola no combina ni separa Geometry incorrectament.

La world position, rotation i scale del Node no formen part de la Geometry Signature. Dues Geometry amb el mateix nombre de vèrtexs i cares es mantenen en Groups separats si les posicions reals o la topology són diferents. Els Mesh amb vertex index reconstruït completament i el fuzzy o rotation-invariant matching queden fora de l'abast de MK1.

Les instàncies amb el mateix `baseObject` i sense Modifiers reutilitzen una Signature en cache. Un Node amb Modifiers es pot classificar a partir de l'evaluated Mesh, però durant Instance Normalize es tracta de manera conservadora com a `STACK UNSAFE / INSTANCE SKIPPED`.

## Principis de seguretat

- Analyze no modifica la Scene.
- Rename només canvia el nom i fa servir noms temporals en dues fases per evitar col·lisions.
- Instance Normalize fa servir el patró verificat per Lunar Transform Assistant: `target.baseObject = source.baseObject`.
- Abans i després de crear la relació d'Instance es verifiquen transform, position, rotation, scale, pivot/object offset, parent, layer, material, hidden/frozen/visibility, wire color i world bounds.
- Si la verificació falla, el Base Object original es restaura immediatament i el Node es marca com a `INSTANCE UNSAFE`.
- L'eina no executa Center Pivot, Reset XForm, Collapse, Attach, conversió forçada a Editable Poly, Transform Bake, consolidació de Material, canvis de Layer/Visibility ni operacions de tyFlow.

Cada botó que modifica la Scene crea una unitat Undo. Tot `APPLY ALL` es pot revertir amb una sola operació `Undo "Lunar Geometry Preprocessor"`.

## Proves

`tests\LunarGeometryPreprocessor_smoke.ms` cobreix:

- classificació de Geometry idèntica independentment de position/rotation/scale;
- separació de Geometry diferent amb el mateix nombre de vèrtexs i cares;
- invariància de l'estat del Source durant Analyze;
- selecció de Groups;
- bloqueig de Suggested Names duplicats i de col·lisions amb noms externs;
- Rename determinista de tres dígits i invariància de Rename Only;
- conversió de Copy a Instance preservant transform, pivot i material de cada Node;
- conversió exclusiva de les dues Copies en un conjunt de vuit Instances i dues Copies;
- omissió conservadora d'Instance quan hi ha un Modifier Stack.

## Llicència

Aquesta eina es distribueix sota la GNU General Public License v3.0. Consulteu [../LICENSE](../LICENSE) per obtenir-ne els detalls.
