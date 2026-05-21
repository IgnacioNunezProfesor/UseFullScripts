# UseFullScripts

Colección de scripts PowerShell útiles para administración y mantenimiento de sistemas Windows 11. Estos scripts automatizan tareas comunes de limpieza, actualización y configuración del sistema operativo.

**⚠️ ADVERTENCIA:** La mayoría de estos scripts requieren permisos de administrador. Algunos pueden modificar la configuración del sistema, por lo que se recomienda hacer una copia de seguridad antes de ejecutarlos.

---

## 📋 Tabla de Contenidos

- [Requisitos Previos](#requisitos-previos)
- [Cómo Ejecutar los Scripts](#cómo-ejecutar-los-scripts)
- [Descripción de Scripts](#-descripción-de-scripts)
- [Personalización del Terminal](#-personalización-del-terminal)
- [Notas de Seguridad](#-notas-de-seguridad)

---

## Requisitos Previos

- **Windows 11** (la mayoría de scripts están optimizados para W11)
- **PowerShell 5.0 o superior**
- **Acceso de administrador** (requerido por todos los scripts)
- Para algunos scripts: **7-Zip** (para UnzipAll.ps1)
- Para algunos scripts: **Winget** (para UpdateAll.ps1)

### Habilitación de Scripts PowerShell

Si obtienes un error de ejecución, ejecuta esto en PowerShell como administrador:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Cómo Ejecutar los Scripts

### Opción 1: Desde PowerShell (Recomendado)

```powershell
# Navegar a la carpeta del script
cd \UseFullScripts

# Ejecutar un script
.\CleanW11.ps1

# O ejecutar directamente con el atajo completo
powershell -ExecutionPolicy Bypass -File .\CleanW11.ps1
```

### Opción 2: Crear un Acceso Directo

Clic derecho en el script → **Crear acceso directo** → Editar propiedades:

- Destino: `powershell.exe -ExecutionPolicy Bypass -File "C:\ruta\al\script.ps1"`
- Opciones avanzadas → Marcar "Ejecutar como administrador"

---

## 📝 Descripción de Scripts

### 1. **CleanW11.ps1**

**Propósito:** Limpieza profunda de archivos temporales y caché del sistema Windows 11

**Qué Hace:**

- Detiene temporalmente el servicio `wuauserv` (Windows Update)
- Limpia carpetas de archivos temporales:
  - `%TEMP%` (archivos temporales del usuario)
  - `C:\Windows\Temp` (archivos temporales del sistema)
  - `C:\Windows\SoftwareDistribution\Download` (caché de actualizaciones)
  - `C:\Windows\Prefetch` (archivos preformateados)
- Vacía la Papelera de Reciclaje
- Reinicia el servicio de Windows Update

**Requisitos:** Permisos de administrador

**Cuándo Usarlo:**

- Cuando el sistema esté lento
- Después de eliminar programas grandes
- Para liberar espacio en disco
- Como mantenimiento preventivo mensual

**Tiempo Aproximado:** 2-5 minutos

```powershell
.\CleanW11.ps1
```

---

### 2. **EnableDisableHypervisor.ps1**

**Propósito:** Activar o desactivar el Hipervisor de Windows (Hyper-V, virtualización)

**Qué Hace:**

- Verifica el estado actual del Hipervisor
- Si está **ACTIVADO**: Lo desactiva
- Si está **DESACTIVADO**: Lo activa
- Muestra el estado resultante

**Requisitos:**

- Permisos de administrador
- Procesador compatible con virtualización

**Cuándo Usarlo:**

- Cuando quieras usar software de virtualización como VirtualBox o VMware (desactivar Hyper-V)
- Cuando necesites Hyper-V para máquinas virtuales (activar)
- Para troubleshooting de problemas de rendimiento

**Nota Importante:** Requiere **reinicio** del sistema para aplicar cambios

```powershell
.\EnableDisableHypervisor.ps1
```

---

### 3. **RunADefender.ps1**

**Propósito:** Actualizar las definiciones de virus y realizar escaneo completo con Microsoft Defender

**Qué Hace:**

- Ubica la herramienta de línea de comandos de Defender (`MpCmdRun.exe`)
- Descarga las últimas definiciones de virus y malware
- Ejecuta un escaneo completo del sistema
- Muestra indicadores visuales del progreso

**Requisitos:**

- Permisos de administrador
- Microsoft Defender instalado y activo

**Cuándo Usarlo:**

- Mantenimiento de seguridad regular (semanal o mensual)
- Después de detectar comportamientos sospechosos
- Como parte de una rutina de limpieza

**Tiempo Aproximado:** 15-45 minutos (depende del tamaño del disco)

```powershell
.\RunADefender.ps1
```

---

### 4. **ToggleTelemetryW11.ps1**

**Propósito:** Activar o desactivar la telemetría y recopilación de datos de Windows 11

**Qué Hace:**

- Permite elegir entre **Enable** (Activar) o **Disable** (Desactivar)
- Modifica la configuración de recopilación de datos en el registro
- Detiene/inicia servicios de telemetría:
  - `DiagTrack` (Servicio de Experiencia conectada de diagnóstico)
  - `dmwappushsvc` (Notificaciones push de aplicaciones)
  - `diagnosticshub.standardcollector.service` (Recopilación de diagnósticos)

**Requisitos:** Permisos de administrador

**Cuándo Usarlo:**

- **Desactivar:** Para mejorar privacidad, reducir el uso de internet o cuando trabajes con datos sensibles
- **Activar:** Para problemas de diagnóstico o si necesitas que Microsoft recaba datos de tu sistema

**Ejemplos de Uso:**

```powershell
# Desactivar telemetría
.\ToggleTelemetryW11.ps1 -State Disable

# Activar telemetría
.\ToggleTelemetryW11.ps1 -State Enable
```

---

### 5. **UnzipAll.ps1**

**Propósito:** Extraer recursivamente archivos .zip y .rar en una carpeta y sus subcarpetas

**Qué Hace:**

- Busca todos los archivos `.zip` y `.rar` en la carpeta raíz especificada
- Extrae cada archivo en su carpeta contenedora (no crea subcarpetas adicionales)
- Utiliza 7-Zip como herramienta de descompresión
- Soporta búsqueda recursiva en subcarpetas

**Requisitos:**

- Permisos de lectura/escritura en la carpeta
- **7-Zip instalado** (ubicaciones por defecto: `Program Files` o `Program Files (x86)`)

**Uso:**

```powershell
# Parámetro obligatorio: -Root o posición 0
.\UnzipAll.ps1 -Root ".\Descargas"

# O sin nombre de parámetro
.\UnzipAll.ps1 ".\Descargas"
```

**Ejemplo Práctico:**

```text
Estructura antes:
C:\Datos\
├── archivo1.zip
└── Subcarpeta\
    └── archivo2.rar
```

```text
Estructura después (después del script):
C:\Datos\
├── archivo1 (archivos extraídos)
└── Subcarpeta\
    └── archivo2 (archivos extraídos)
```

**Cuándo Usarlo:**

- Descargas en lote que necesitan extracción
- Organizando archivos comprimidos
- Automatizando procesos de preparación de datos

---

### 6. **UpdateAll.ps1**

**Propósito:** Actualizar el sistema completo: Windows, aplicaciones de Microsoft Store y software instalado

**Qué Hace:**

- **Actualización de Windows:** Busca e instala todas las actualizaciones disponibles del SO
- **Microsoft Store:** Actualiza todas las aplicaciones de la tienda
- **Winget:** Actualiza todo el software instalado que fue instalado con Winget
- **Office 365:** Actualiza Microsoft Office si está instalado

**Requisitos:**

- Permisos de administrador
- Conexión a internet
- Winget instalado (disponible en Windows 11 por defecto)
- PSWindowsUpdate (el script lo instala automáticamente)

**Cuándo Usarlo:**

- Actualización completa del sistema (semanal o mensual)
- Antes de instalar software nuevo
- Tras reinstalar Windows

**Advertencia:** El sistema puede reiniciarse automáticamente tras las actualizaciones

```powershell
.\UpdateAll.ps1
```

---

### 7. **WupdateError.ps1**

**Propósito:** Reparar errores de Windows Update limpiando caché y reconfigurando servicios

**Qué Hace:**

- Detiene los servicios relacionados con Windows Update:
  - `wuauserv` (Windows Update)
  - `cryptSvc` (Servicio Criptográfico)
  - `bits` (Servicio de Transferencia Inteligente de Fondo)
  - `msiserver` (Instalador de Windows)
- Renombra carpetas de caché problemas:
  - `C:\Windows\SoftwareDistribution` → `SoftwareDistribution.old`
  - `C:\Windows\System32\catroot2` → `catroot2.old`
- Reinicia los servicios
- Ejecuta herramientas de reparación:
  - **DISM** (Deployment Image Servicing and Management)
  - **SFC** (System File Checker - Comprobador de archivos de sistema)

**Requisitos:** Permisos de administrador

**Cuándo Usarlo:**

- Cuando Windows Update falla o se queda atascado
- Errores tipo `0x80070490`, `0x80073712`, etc.
- Cuando el sistema no puede instalar actualizaciones
- Después de actualizaciones fallidas

**Importante:**

- El escaneo SFC puede tardar 30+ minutos
- Se recomienda **reiniciar el sistema** después de este script
- Tras el reinicio, intenta actualizar nuevamente

```powershell
.\WupdateError.ps1
```

---

## 🎨 Personalización del Terminal

### **InstallOHMyPosh.ps1**

**¿Qué es Oh My Posh?**
Es un motor de temas para cualquier shell que permite personalizar el prompt de tu terminal con iconos, colores y datos útiles (como el estado de Git, nivel de batería o versión de Node.js).

**Qué Hace el Script:**
- Instala **Oh My Posh** mediante Winget.
- Instala una **Nerd Font** (Meslo LGM NF) necesaria para ver los iconos correctamente.
- Configura tu perfil de PowerShell (`$PROFILE`) para que el tema se cargue automáticamente al abrir la terminal.
- Establece un tema predeterminado (puedes cambiarlo editando el perfil).

**Requisitos:**
- Conexión a internet.
- Ejecutar PowerShell como administrador para la instalación de fuentes.

**Uso:**
```powershell
.\InstallOHMyPosh.ps1
```

**Nota:** Después de la ejecución, es posible que debas cambiar la fuente de tu terminal (Windows Terminal -> Configuración -> Perfiles -> Apariencia -> Fuente) a **"MesloLGM Nerd Font"** para que los iconos se vean correctamente.

**Tiempo Aproximado:** 3-5 minutos.

---

## 🔒 Notas de Seguridad

### ⚠️ Requerimientos de Administrador

Todos estos scripts requieren permisos elevados de administrador. Si se ejecutan sin privilegios, se relanzarán automáticamente solicitando permisos.

### 📌 Recomendaciones

1. **Hacer Copia de Seguridad:**
   - Realiza un punto de restauración antes de ejecutar scripts de reparación
   - Espacio libre en disco: al menos 5-10 GB

2. **Desactivar Antivirus Temporal:**
   - Algunos scripts pueden activar alertas de seguridad
   - Es seguro desactivar temporalmente la protección en tiempo real

3. **Conexión a Internet:**
   - Mantén conexión estable durante actualizaciones
   - UpdateAll.ps1 puede descargar cientos de MB

4. **No Usar en Sistemas Críticos:**
   - Prueba primero en máquinas virtuales o de desarrollo
   - WupdateError.ps1 es más agresivo; usarlo como último recurso

### 📋 Orden Recomendado de Ejecución

```text
1. RunADefender.ps1        → Escanear para detectar malware
2. UpdateAll.ps1           → Actualizar Windows y aplicaciones
3. CleanW11.ps1            → Limpiar archivos temporales
4. WupdateError.ps1        → Solo si hay errores de actualización
5. EnableDisableHypervisor → Si necesitas cambiar configuración
6. ToggleTelemetryW11.ps1  → Privacidad (opcional)
```

---

## 📞 Solución de Problemas

### El script no se ejecuta

```powershell
# Verificar política de ejecución
Get-ExecutionPolicy

# Permitir scripts locales
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Acceso denegado / No hay suficientes permisos

- Ejecuta PowerShell como administrador (clic derecho → "Ejecutar como administrador")
- Los scripts incluyen auto-elevación, pero a veces necesita confirmación manual

### El script se abre y cierra rápidamente

- Abre PowerShell como administrador
- Navega a la carpeta del script
- Ejecuta manualmente: `.\ScriptName.ps1`

---

## 📄 Licencia

Estos scripts se proporcionan tal como están. Úsalos bajo tu responsabilidad.

---

**Última actualización:** Enero 2026
