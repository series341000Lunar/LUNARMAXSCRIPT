# Renew Parent Animation

[한국어](README.md) · [Català](README.ca.md)

A Blender 4.x, l'eina captura primer la **transformació World avaluada** de tots els Child durant tot el rang de fotogrames de l'escena. Després estableix l'objecte actiu com a Parent i crea una Action relativa al Parent amb claus `location`, `rotation_quaternion` i `scale`. No modifica les dades de Mesh ni de Material dels Child.

## Instal·lació i ús

1. Instal·la i activa [renew_parent_animation.py](renew_parent_animation.py) amb `Edit > Preferences > Add-ons > Install from Disk`. S'ha executat com a Add-on d'un sol fitxer a Blender 4.4/4.5.
2. Selecciona primer els Child i, al final, el Parent com a Active Object. Admet diversos Child.
3. Executa `N > Animation Tools > Renew Parent Animation` a la 3D View.

El Bake recorre `scene.frame_start` fins a `scene.frame_end` amb pas d'un fotograma. La System Console mostra l'error màxim de posició (unitats Blender) i de rotació (graus), global i per Child. Les toleràncies són `0.0001` i `0.01°`; si se superen, s'emet un Warning. Es restauren el fotograma, la selecció i l'Active Object; l'Operator admet Undo.

## Abast i límits

- La captura usa el `matrix_world` final del Dependency Graph. No es canvien Parent, Constraint ni Action fins que s'han capturat tots els fotogrames.
- Els Constraint i NLA Track anteriors dels Child es posen en mute, igual que els Transform Driver. L'Action anterior continua com a datablock però deixa de ser l'Action activa. L'Action nova té claus `LINEAR` a cada fotograma. Altres canals d'Object Action o NLA que no són transformacions també poden quedar desactivats.
- També es cou Scale. Si la matriu relativa conté Shear que un Object TRS no pot representar, l'operació s'atura abans dels canvis. La validació cobreix els fotogrames enters mostrejats; la precisió de Blender i la interpolació entre fotogrames poden diferir.
- No es modifica l'Animation/Cache del Parent. Si el Parent depèn d'un Cache extern, la reproducció de tota la jerarquia continua necessitant aquella font. No s'ha provat un fitxer USD/ABC Transform Cache real en aquesta sessió.
- L'Action nova del Child conté claus natives d'Object Transform i s'avalua sense el seu Transform Cache Constraint anterior. Per recuperar la font anterior, cal gestionar els estats mute manualment o fer Undo.

## Verificació

```powershell
& 'C:\Program Files\Blender Foundation\Blender 4.5\blender.exe' -b --factory-startup --python 'RenewParentAnimation\tests\test_renew_parent_animation.py'
```

L'[script de proves](tests/test_renew_parent_animation.py) executa A Translation, B Translation+Rotation, C Multiple Children, D Constraint-driven Child i E Driver/NLA Source a Blender 4.4.3/4.5.3. També comprova el Rollback d'un error a mig Bake, el rebuig d'un Parent cycle i d'una Singular Matrix. Cada prova compara el World motion avaluat dels Child abans i després als fotogrames 1–11.
