# Trabajo colaborativo

Repositorio del equipo: https://github.com/eperezv23/Proyecto-Final

Para compartir la lectura basta con enviar ese enlace mientras el repositorio
sea público. Para que un compañero pueda subir cambios, el propietario debe
invitar su usuario de GitHub como colaborador. No se enviaron invitaciones ni
se modificó la visibilidad del repositorio.

## Ramas y cambios

- `main`: versión estable que se presenta.
- `develop`: integración de cambios revisados.
- `feature/nombre`: una funcionalidad específica.
- `fix/nombre`: una corrección concreta.

```bash
git clone https://github.com/eperezv23/Proyecto-Final.git
cd Proyecto-Final
git switch develop
git pull --ff-only origin develop
git switch -c feature/mi-tarea
```

Editar los scripts y la documentación de la tarea. Comprobar instalación y
pruebas en una base nueva propia. Cada desarrollador usa su propia base local;
no se comparte un archivo MDF ni se versionan respaldos con datos personales.

```bash
git add sql/ docs/
git commit -m "feat: describir la funcionalidad concreta"
git push -u origin feature/mi-tarea
```

Abrir un Pull Request hacia `develop`, describir el comportamiento que cambia
y adjuntar resultados de pruebas. Un compañero revisa consultas, transacciones
y compatibilidad antes de fusionar. Para publicar una versión estable se abre
otro Pull Request de `develop` hacia `main`.

## Sincronización y conflictos

Antes de empezar una tarea, actualizar `develop`. Para integrar cambios durante
el trabajo, guardar primero el avance en un commit de la rama propia:

```bash
git fetch origin
git merge origin/develop
```

Si existen conflictos, revisar los bloques marcados en cada archivo y conservar
el comportamiento correcto de ambos cambios. Ejecutar otra vez las pruebas,
hacer `git add` de los archivos resueltos y completar el commit de combinación.
No usar `push --force` sobre `main` o `develop`.

## Revisión y tareas

Utilizar Issues para registrar un problema reproducible, resultado esperado,
prioridad y criterio de aceptación. Un Issue debe corresponder a una tarea
concreta. Las plantillas en `.github/` ayudan a preparar Issues y Pull Requests.

La protección de `main` queda como configuración del propietario: exigir
Pull Request, al menos una revisión y evitar borrados o envíos forzados.
No se aplicó esa configuración de permisos automáticamente. Revisar qué
protecciones admite la cuenta antes de activarlas.

Antes de publicar, revisar `git diff --cached` y comprobar que no haya
credenciales, identificaciones reales, archivos `.env` ni respaldos SQL.
