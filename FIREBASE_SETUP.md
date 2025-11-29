# Configuración de Firebase para Buses Suray

## Estructura de Firestore

### Colección: `ruta_estaciones`

Esta colección almacena todas las estaciones de la Ruta 240. Cada documento representa una estación.

#### Campos de cada documento:

```javascript
{
  "name": "REMANSÓ",           // Nombre corto de la estación (obligatorio)
  "fullName": "Remansó",       // Nombre completo de la estación (obligatorio)
  "km": 0,                     // Kilómetro de la estación (obligatorio, número entero)
  "activo": true,              // Si la estación está activa (obligatorio, booleano)
  "isTerminal": true,          // Si es una terminal (opcional, booleano, default: false)
  "icon": null                 // Icono personalizado (opcional, string)
}
```

### Ejemplo de estaciones basadas en la imagen:

```javascript
// Terminal inicial (KM 0)
{
  "name": "REMANSÓ",
  "fullName": "Remansó",
  "km": 0,
  "activo": true,
  "isTerminal": true
}

// Estaciones intermedias
{
  "name": "YUNQUIHUAL",
  "fullName": "Yunquihual",
  "km": 8,
  "activo": true,
  "isTerminal": false
}

{
  "name": "MANGERAS",
  "fullName": "Mangeras",
  "km": 10,
  "activo": true,
  "isTerminal": false
}

{
  "name": "LLOLCAS",
  "fullName": "Llolcas",
  "km": 12,
  "activo": true,
  "isTerminal": false
}

{
  "name": "CALLE CALLE",
  "fullName": "Calle Calle Naturalidad",
  "km": 20,
  "activo": true,
  "isTerminal": false
}

{
  "name": "ULTRA REGIÓN",
  "fullName": "Ultra Región",
  "km": 21,
  "activo": true,
  "isTerminal": false
}

{
  "name": "CLURASU",
  "fullName": "Clurasu",
  "km": 23,
  "activo": true,
  "isTerminal": false
}

{
  "name": "RUTA",
  "fullName": "Ruta",
  "km": 25,
  "activo": true,
  "isTerminal": false
}

{
  "name": "MENETORIES",
  "fullName": "Menetories",
  "km": 27,
  "activo": true,
  "isTerminal": false
}

{
  "name": "CASTILLE",
  "fullName": "Castille Leandro-Guayez",
  "km": 32,
  "activo": true,
  "isTerminal": false
}

{
  "name": "CASINO YPICH",
  "fullName": "Casino Ypich",
  "km": 33,
  "activo": true,
  "isTerminal": false
}

{
  "name": "RAUSCUSASTÍN",
  "fullName": "Rauscusastín",
  "km": 35,
  "activo": true,
  "isTerminal": false
}

{
  "name": "EL RASGO",
  "fullName": "El Rasgo Velo Fluxo Belenlino",
  "km": 60,
  "activo": true,
  "isTerminal": false
}

{
  "name": "RAUL",
  "fullName": "Raul",
  "km": 61,
  "activo": true,
  "isTerminal": false
}

{
  "name": "CLARTE",
  "fullName": "Fyl Clarte Transline",
  "km": 62,
  "activo": true,
  "isTerminal": false
}

{
  "name": "UITRALLE",
  "fullName": "Uitralle",
  "km": 67,
  "activo": true,
  "isTerminal": false
}

// Terminal final (ajusta el KM según corresponda)
{
  "name": "COYHAIQUE",
  "fullName": "Terminal Coyhaique",
  "km": 68,
  "activo": true,
  "isTerminal": true
}
```

## Índices necesarios en Firestore

Para optimizar las consultas, crea los siguientes índices compuestos:

1. **Colección**: `ruta_estaciones`
   - **Campos**:
     - `activo` (Ascending)
     - `km` (Ascending)

## Cómo agregar estaciones desde la consola de Firebase

1. Ve a Firebase Console
2. Navega a Firestore Database
3. Busca o crea la colección `ruta_estaciones`
4. Haz clic en "Agregar documento"
5. Firebase generará un ID automáticamente
6. Agrega los campos según la estructura descrita arriba
7. Guarda el documento

## Modificar estaciones existentes

Para modificar una estación:
1. Ve a la colección `ruta_estaciones`
2. Encuentra el documento que deseas modificar
3. Haz clic en el documento
4. Edita los campos necesarios
5. Guarda los cambios

Los cambios se reflejarán automáticamente en la app cuando se recargue el mapa de ruta.

## Desactivar estaciones

Para ocultar temporalmente una estación sin eliminarla:
1. Encuentra el documento de la estación
2. Cambia el campo `activo` a `false`
3. Guarda los cambios

La estación dejará de mostrarse en el mapa pero permanecerá en la base de datos.

## Notas importantes

- El campo `km` debe ser un número entero (no string)
- Las estaciones se ordenan automáticamente por kilómetro
- Solo se muestran estaciones con `activo: true`
- Los terminales (`isTerminal: true`) se muestran con un diseño especial
- El mapa es totalmente horizontal y se puede desplazar
- Incluye una animación de bus que recorre la ruta de izquierda a derecha
