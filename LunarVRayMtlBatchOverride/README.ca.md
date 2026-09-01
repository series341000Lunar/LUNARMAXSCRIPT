# Lunar VRayMtl Batch Override

[한국어](README.md) · [Català](README.ca.md)

Utilitat MAXScript independent que modifica en lot només els Parameters marcats i només a les instàncies `VRayMtl` seleccionades directament per l'usuari a la vista activa de Slate Material Editor.

Fitxer executable: `src/Lunar_VRayMtl_Batch_Override.ms`

## Ús

1. Obriu Slate Material Editor i seleccioneu a la vista actual els Nodes `VRayMtl` que voleu modificar.
2. Executeu l'script.
3. Marqueu només els Parameters que voleu canviar i configureu els valors i Map Handling.
4. Premeu `Apply to Selected VRayMtl`. En el moment de l'Apply es torna a llegir la selecció actual de l'SME.

L'eina no consulta ni modifica la selecció de Scene Objects, Material Assignment, Material ID, Face Material ID ni els submaterials Multi/Sub. Si la mateixa referència de material apareix més d'una vegada, es processa una sola vegada segons la referència real.

## Abast de la implementació

- Base / Diffuse Color
- Reflection Color
- Reflection Surface: Glossiness o Roughness
- Metalness
- Refraction Color
- Refraction Glossiness
- Map Handling: Keep, Disable o Remove
- Restauració de tot l'Apply amb un sol Undo
- Bloqueig d'Apply duplicat i aïllament d'errors per Material/Parameter
- Diagnòstic read-only de Properties del primer `VRayMtl` seleccionat

Tots els checkboxes d'Override estan desactivats per defecte i el valor inicial de Map Handling és Keep. No s'accedeix ni s'escriu cap valor o map d'un Parameter que no estigui marcat.

## API de selecció de l'SME

L'eina fa servir `sme.activeView`, `sme.GetView()` i `view.GetSelectedNodes()`. Llegeix la `reference` real de cada Node Interface i comprova amb `superClassOf` i `classOf` que sigui exactament un `VRayMtl`. No infereix el tipus de material a partir del nom.

## Properties de VRayMtl verificades a l'entorn actual

Els noms següents s'han diagnosticat amb `getPropNames` sobre el `VRayMtl` instal·lat a 3ds Max 2026.3.3 i s'han confirmat amb `isProperty` i proves reals de lectura i escriptura.

| Significat | Value Property | Map Property | Map Enable Property |
|---|---|---|---|
| Base / Diffuse Color | `Diffuse` | `texmap_diffuse` | `texmap_diffuse_on` |
| Reflection Color | `Reflection` | `texmap_reflection` | `texmap_reflection_on` |
| Reflection Surface | `reflection_glossiness` | `texmap_reflectionGlossiness` | `texmap_reflectionGlossiness_on` |
| Metalness | `reflection_metalness` | `texmap_metalness` | `texmap_metalness_on` |
| Refraction Color | `Refraction` | `texmap_refraction` | `texmap_refraction_on` |
| Refraction Glossiness | `refraction_glossiness` | `texmap_refractionGlossiness` | `texmap_refractionGlossiness_on` |

El selector de mode de Reflection Surface és `brdf_useRoughness`.

## Tractament de Glossiness / Roughness

Reflection Surface estableix primer `brdf_useRoughness` al mode escollit i després escriu directament el valor introduït per l'usuari a `reflection_glossiness`. Per tant, Roughness `0.40` no s'inverteix: es desa com a `0.40` en mode Roughness.

Refraction Glossiness escriu directament el valor de l'usuari a `refraction_glossiness`. No aplica `1.0 - value` ni modifica el mode existent de `brdf_useRoughness`.

## Compatibilitat de versió i comportament segur

La capa de compatibilitat normalitza cada candidate String o Name a Name i fa servir com a criteri final `isProperty material propertyName` sobre la referència real del Material. `getPropNames` només s'utilitza per al diagnòstic del Listener; el resolver no en depèn. No es busquen noms aproximats, prefixos ni sufixos.

- Si el Value Property no es pot confirmar, només aquell Parameter es registra com a `Unsupported` i el procés continua.
- Si el Map Property o l'Enable Property no es poden confirmar, el Map es conserva.
- Disable conserva la Map Reference i només desactiva l'Enable Property corresponent.
- Remove assigna `undefined` únicament a la Map Reference del Parameter marcat.
- Els alias d'altres versions de V-Ray no es consideren compatibles fins que s'hagin verificat realment.
- Reflection Surface només és compatible quan es confirmen tant `reflection_glossiness` com `brdf_useRoughness`.

## Resultats de validació

S'han executat `tests/Lunar_VRayMtl_Batch_Override_smoke.ms` i `tests/Lunar_VRayMtl_Batch_Override_sme_regression.ms` amb l'execució quiet/silent de MAXScript a 3ds Max 2026.3.3.

- Regressió general: `Passed: 37`, `Failed: 0`
- Resultat per Parameter sobre 12 `VRayMtl` reals a l'SME: `Passed: 9`, `Failed: 0`
- Base Color: `Success 12 | Unsupported 0 | Errors 0`
- Reflection Color: `Success 12 | Unsupported 0 | Errors 0`
- Surface: `Success 12 | Unsupported 0 | Errors 0`
- Metalness: `Success 12 | Unsupported 0 | Errors 0`
- Refraction Color: `Success 12 | Unsupported 0 | Errors 0`
- Refract Gloss: `Success 12 | Unsupported 0 | Errors 0`
- Confirmació directa amb `isProperty` dels set Value/Mode Properties
- Canvi i restauració reals de `Diffuse`
- Validació de valors i modes V-Ray, i de Map Keep/Disable/Remove
- Conservació dels valors i Maps no marcats
- Cap canvi quan tots els Overrides són OFF
- Protecció de Physical Material, Standard Material i Map
- Aplicació a 50 `VRayMtl` i restauració de valors i Maps eliminats amb un sol Undo
- Verificació de Selection, filtratge de `VRayMtl` i recompte de Skipped en una vista temporal real de l'SME
- Reducció de tres Nodes amb la mateixa referència a un únic Target `VRayMtl`
- Verificació de l'estat inicial OFF, del mode Keep i de la vinculació dels Controls desactivats

`tests/VRayMtl_property_probe.ms` és l'script de diagnòstic per tornar a inspeccionar les Properties del `VRayMtl` instal·lat. En una altra build de V-Ray, reviseu-ne el resultat abans d'actualitzar la taula de compatibilitat.

## Llicència

Aquesta eina es distribueix sota la GNU General Public License v3.0. Consulteu [../LICENSE](../LICENSE) per obtenir-ne els detalls.
