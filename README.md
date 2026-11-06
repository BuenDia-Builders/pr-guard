# pr-guard

Workflows reusables para revisar PRs externos en los repos de BuenDia-Builders
antes de mergear: lint de seguridad de GitHub Actions (`actionlint`, `zizmor`),
dependencias (`dependency-review-action`), y un risk score heuristico del
perfil del autor (cuenta nueva, patron de mass-forking, primera contribucion).

## Como instalarlo en un repo

Copiar los dos archivos de `templates/` a `.github/workflows/` del repo:

```
templates/pr-guard-scan.yml    -> .github/workflows/pr-guard-scan.yml
templates/pr-guard-comment.yml -> .github/workflows/pr-guard-comment.yml
```

El primero corre sin privilegios sobre el codigo del PR (incluso de forks).
El segundo corre despues, con permiso de comentar, pero nunca ejecuta codigo
del PR: solo lee el reporte que dejo el primero como artefacto.

## Que NO hace

No reemplaza la revision manual del diff. Es una primera linea de defensa
contra los vectores mas comunes (workflow injection, dependencias maliciosas,
cuentas de mass-forking tipo bounty farming). El codigo fuente en si
(ej. un backdoor en un contrato) sigue necesitando ojo humano.
