# Lunar → tyFlow Placement MK1

[한국어](README.md) · [Català](README.ca.md)

`LunarTyFlowPlacement_MK1.ms` agrupa en Families, segons el nom, els Source Objects de 3ds Max col·locats manualment a C4D i crea o actualitza un Event `LUNAR_` per a cada Family dins d'un únic tyFlow registrat.

## Execució

1. Executeu `src/LunarTyFlowPlacement_MK1.ms` amb `Run Script...` a 3ds Max.
2. Seleccioneu un sol tyFlow de destinació i premeu `Use Selected tyFlow`.
3. Seleccioneu els Source Objects col·locats. Si el tyFlow de destinació també és a la Selection, s'exclou automàticament.
4. Executeu `ANALYZE` i reviseu Family, Count, Shape Source i Status.
5. Executeu `BUILD / UPDATE`.

## Regles de Family

- Només s'elimina l'últim `_<digits>`: `Cup_015 → Cup`, `Small_Pot_002 → Small_Pot`.
- No s'intenta eliminar números de noms que no coincideixen amb aquesta regla, com `Kettle001`, `Point001` o `B52`.
- Un Node amb nom no estàndard fa servir el nom complet com a Family independent i mostra el Warning `NONSTANDARD NAME`.
- El primer Node vàlid de cada Family segons l'ordre d'entrada d'Analyze es converteix en Shape Source.

## Opcions

- `Ignore Instance Relationship` està activat per defecte. Quan és ON, els Nodes s'agrupen només pel nom i no es comprova la relació Geometry/Instance.
- Quan és OFF, es comprova que tots els Nodes de la Family comparteixin la mateixa referència `baseObject` que el Shape Source. Si no és així, només aquella Family s'omet amb `INSTANCE / GEOMETRY MISMATCH`.
- `Update Existing LUNAR Events` està activat per defecte. Si ja existeix un Event `LUNAR_<Family>`, se n'actualitzen Birth Objects i Shape. Quan és OFF, l'Event existent s'omet amb `ALREADY EXISTS`.

## Estructura generada i límits de seguretat

Cada Event de Family configura els Operators en aquest ordre:

- Birth Objects
  - `objectList`: Source Nodes resolts novament a partir dels handles desats durant Analyze
  - `objectsInheritGeometry = false`
  - `objectsCenterPivots = false`
  - `inheritPosition / inheritRotation / inheritScale = true`
- Shape
  - `shape_type_tab = #(2)` — mode Reference Object
  - `instancedGeo_tab = #(Shape Source)`
  - `meshCenterPivots_tab = #(false)`
  - `scale_tab = #(false)`
- Mesh
  - `meshType = 0` — `TriMesh`
  - `renderOnly = true` — `[Render]`
- Display
  - `displayMode = 4` — `Geometry`

L'estructura final és `Birth Objects → Shape → Mesh (TriMesh [Render]) → Display (Geometry)`.

L'eina no modifica transform, pivot offset, geometry, visibility, hidden/frozen state, layer ni parent dels Source Nodes. No cerca, modifica ni elimina Events o Operators existents que no comencin per `LUNAR_`. Build/Update s'executa en una sola unitat Undo. Si falla la configuració d'un Event nou, l'Event s'elimina; si falla l'actualització d'un Event LUNAR existent, se'n restauren els valors anteriors dels Operators.

## Entorn de validació

- Autodesk 3ds Max 2026.3.3 Security Fix
- `tyFlow_2026.dlo` instal·lat, versió `2.0100.0.0`
- `tests/LunarTyFlowPlacement_smoke.ms`: 39 Passed / 0 Failed

Les proves cobreixen classificació de noms, una o diverses Families, ignore/validation de les Instances, protecció d'Events existents, Update/Skip, Shape Source eliminat, invariància del Source i també els resultats reals de particle Position/Rotation/Scale i Shape mesh.

## Llicència

Aquesta eina es distribueix sota la GNU General Public License v3.0. Consulteu [../LICENSE](../LICENSE) per obtenir-ne els detalls.
