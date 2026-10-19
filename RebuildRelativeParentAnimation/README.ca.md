# Rebuild Relative Parent Animation

Eina MAXScript per a 3ds Max que converteix animacions World Transform independents en una jerarquia Parent real i claus PRS locals editables als Children. No necessita biblioteques externes.

## Ús

A 3ds Max, executeu [`src/LG_RebuildRelativeParentAnimation.ms`](src/LG_RebuildRelativeParentAnimation.ms) amb **Scripting > Run Script**. Amb la finestra oberta, seleccioneu primer els Children i afegiu el Parent **com a últim Node, individualment**. Després premeu **Rebuild Relative Parent Animation**. L'eina no dedueix el Parent de l'ordre de l'array `selection`: registra l'últim Node afegit mentre la finestra és oberta. Si tots els Nodes ja estaven seleccionats o se n'afegeixen diversos alhora, indiqueu el Parent amb **Pick Parent (fallback)**. Amb el Parent indicat explícitament, la resta de Nodes seleccionats són els Children.

El rang és `animationRange.start` a `animationRange.end`, amb un pas d'1 frame. **Bake Scale** està desactivat per defecte. El temps actual i la selecció es mantenen; un sol Undo desfà tota l'operació. En cas d'error, els canvis es cancel·len i el missatge apareix a la UI i al Listener.

## Procés i validació

1. Abans de canviar la jerarquia o els Controllers, captura el World Matrix3 `node.transform` del Parent i de tots els Children a cada frame.
2. Calcula `ChildLocalTM = ChildWorldTM * inverse(ParentWorldTM)`.
3. Assigna el Parent i substitueix el Transform Controller de cada Child per PRS / Position XYZ / Euler XYZ / Scale. Els eixos Position/Euler reben claus Linear Float. No modifica el Controller del Parent.
4. Compara la posició i la rotació World de cada mostra amb l'original. Les toleràncies són `0.0001` scene unit i `0.01°`. Amb Bake Scale activat, també compara la base de la World Matrix. Si se superen, cancel·la la transacció Undo.

No modifica geometry, pivot/object offset, modifiers ni materials, i no crea Dummies ni Constraints temporals.

## Límits

- El mostreig cada frame no reconstrueix exactament el moviment original entre frames. Les claus lineals eviten overshoot, però la trajectòria sub-frame pot diferir.
- Les World Matrices mostrejades no permeten recuperar revolucions completes amagades entre frames. Euler XYZ tria una representació equivalent pròxima al frame anterior.
- Una Parent Matrix singular o una local Matrix amb shear, zero scale o mirror provoca un error. Amb Bake Scale desactivat, no es conserva la diferència d'escala; la validació prioritza Translation i Rotation.
- Encara no s'ha provat amb un fitxer AlembicXform real. L'eina llegeix la World Matrix final sense dependre del Source Controller, i s'ha validat un Source amb Position/Orientation Constraint a 3ds Max Batch.

## Proves

`tests/RRPA_smoke.ms` s'ha executat a 3ds Max 2027 Batch. A Translation, B Parent Rotation/Orbit, C 3 Children, D Position/Orientation Constraint, E jerarquia de 4 nivells, més Scale ON, el límit Euler 180°, substitució d'un Parent existent i rebuig d'un Parent singular, han donat **26 PASS / 0 FAIL**. El resultat queda a `tests/RRPA-smoke-result.txt`. La verificació UI/viewport a l'escena de l'usuari és un pas separat.
