<!-- LANGUAGE_LINKS_START -->
<span style="color: grey;">🇩🇪 German</span> | [🇬🇧 English](README-en.md)
<!-- LANGUAGE_LINKS_END -->

# Docker Buildumgebung

Dieses Repository enthält die notwendigen Dateien, um einen Docker-Container zu konfigurieren, zu erzeugen und zu starten, einschließlich `docker-compose.yaml`, `Dockerfile` und Skripte. Einige Umgebungsvariablen werden in eine `.env`-Datei hinterlegt, die mit dem Skript `create-env.sh` erzeugt werden muss, um einige Einstellungen vom Host-System zu übernehmen. Ein Basis-Dockerimage, wird dabei automatisch von Docker-Hub geladen.

Die Verwendung dieses Repositorys soll helfen, Docker-Container zu erzeugen, die die notwendigen Voraussetzungen bereitstellen, um Neutrino Flashimages und Pakete mit dem Yocto/OE-Buildsystem bauen zu können.

# Inhalt
- [Inhalt](#inhalt)
- [🚀 Schnellstart](#-schnellstart)
  - [Container bauen](#container-bauen)
  - [Auf Container einloggen](#auf-container-einloggen)
  - [Buildumgebung im Docker-Terminal initialisieren](#buildumgebung-im-docker-terminal-initialisieren)
- [1. Voraussetzungen](#1-voraussetzungen)
- [2. Vorbereiten](#2-vorbereiten)
  - [2.1. Repository klonen und in das geklonte Repo wechseln](#21-repository-klonen-und-in-das-geklonte-repo-wechseln)
  - [2.2. Umgebungsvariablen konfigurieren](#22-umgebungsvariablen-konfigurieren)
  - [2.3 Volumes](#23-volumes)
  - [2.4 Ports konfigurieren](#24-ports-konfigurieren)
    - [2.4.1 Webzugriff](#241-webzugriff)
    - [2.4.2 SSH](#242-ssh)
- [3. Container bauen](#3-container-bauen)
  - [3.1 Beispiel 1](#31-beispiel-1)
- [4. Container starten](#4-container-starten)
- [5. Container stoppen](#5-container-stoppen)
- [6. Verwenden des Containers](#6-verwenden-des-containers)
  - [6.1. Einloggen](#61-einloggen)
  - [6.2. Buildumgebung nutzen](#62-buildumgebung-nutzen)
- [7. Container aktualisieren](#7-container-aktualisieren)
- [8. Unterstützung](#8-unterstützung)


# 🚀 Schnellstart

Falls du den Container schnell zum Laufen bringen willst, kannst du die folgenden Schritte in einem Terminal ausführen. Dies setzt voraus, dass Docker und Docker Compose bereits installiert sind.

## Container bauen

```bash
~git clone https://github.com/tuxbox-neutrino/docker-buildenv.git && cd docker-buildenv
                  ./docker-compose build
                  docker-compose up -d
```

## Auf Container einloggen

```bash
~/docker exec -it --user $USER tuxbox-build bash
```

## Buildumgebung im Docker-Terminal initialisieren

```bash
user@asjghd76dfwh:~/tuxbox/buildenv$ ./init && cd poky-3.2.4
...
Create configurations ...
...
Start build
------------------------------------------------------------------------------------------------
Now you are ready to build your own images and packages.
Selectable machines are:

        hd51 ax51 mutant51 bre2ze4k hd60 ax60 hd61 ax61 h7 zgemmah7 osmio4k osmio4kplus e4hdultra

Select your favorite machine (or identical) and the next steps are:

        cd /home/tg/tuxbox/buildenv/poky-3.2.4 && . ./oe-init-build-env build/<machine>
        bitbake neutrino-image

For more information and next steps take a look at the README.md!
user@asjghd76dfwh:~/tuxbox/buildenv/poky-3.2.4$ 
```

Weitere Anpassungen sollte am Container selbst nicht notwendig sein. Nach diesen Schritten läuft der Container im Hintergrund und stellt die Yocto/OE-Buildumgebung bereit.
Du kannst nun mit dem Buildprozess beginnen.

**Hinweis:** Weitere Informationen zum weiteren Vorgehen findest du [hier](https://github.com/tuxbox-neutrino/buildenv/blob/master/README.md) 

# 1. Voraussetzungen

  Getestet wurde unter Linux Debian 11.x, Ubuntu 20.04, 22.04. Es sollte aber auf jeder aktuellen Distribution funktionieren auf der Docker läuft.

  Erforderlich:
     
   - Docker, [Installation](https://docs.docker.com/engine/install/debian/#install-using-the-convenience-script)
   - Docker Compose >= v2.24.3, [Installation](https://docs.docker.com/compose/install/standalone/)
   - Git, Installation über den Paketmanager je nach Distribution
   
  Optional:
   
   - [Docker Desktop](https://www.docker.com/products/docker-desktop/)
   - Portainer, [Installation](https://docs.portainer.io/start/install-ce/server/docker/linux) (mit Docker-Desktop als Plugin verfügbar)

  **Wichtig!** Nachdem Du Docker installiert hast und Docker als nicht Root Benutzer ausführen möchtest, musst Du dich, falls noch nicht geschehen, mit diesem Befehl als Benutzer zur `docker` Gruppe hinzufügen:

   ```bash
   sudo usermod -aG docker $USER
   ```
  Danach zum Übernehmen dieser Änderung ausloggen und wieder einloggen oder einen Neustart durchführen!

# 2. Vorbereiten

## 2.1. Repository klonen und in das geklonte Repo wechseln

   ```bash
   git clone https://github.com/tuxbox-neutrino/docker-buildenv.git && cd docker-buildenv
   ```

## 2.2. Umgebungsvariablen konfigurieren

   Ist noch keine .env Datei vorhanden, muss zumindest einmal diese Datei erzeugt werden.

   Dazu führe dieses Script aus. Du wirst dabei abgerfragt, welche Umgebungsvariablen gesetzt werden sollen. Anpassungen sind normalerweise nicht erforderlich, weil das Script einige Umgebungsvariablen vom Host-System holt und diese in eine `.env`-Datei einbaut:

   ```bash
   ./create-env.sh
   ```
  
  Führst du dieses Script weitere Male aus, kannst du entscheiden ob du es ausführen willst, oder die es dabei belässt.

## 2.3 Volumes

  Der Container verwendet Docker Volumes, um persistente Daten zu speichern, welche Zugriff auf spezifische Dateien und Verzeichnisse dauerhaft im Container ermöglichen.
  In der Standardkonfiguration werden prinzipiell diese Volumes passend zur Umgebung deines Host-Systems eingebunden und beim Starten des Containers eingehängt, so dass Du im Idealfall an der Volumes-Konfiguration nichts ändern musst.
  Solltest Du daran Änderungen vornehmen wollen, findest Du in der `docker-compose.yml` die Konfiguration der Volumes. 
  **Beachte** aber dass diese Einstellungem normalerweise mit den Pfaden wie sie für die Yocto/OE Buildumgebung mit dem init-Script aus dem Buildenv-Repository vorkonfiguriert werden, abgestimmt sind. Sollten daran Anpassungen vorgenommen werden, solltest Du das berücksichtigen!
  
  Diese Pfade werden als Volumes im Container bereitgestellt. Du hast über dein Host darauf normalen Zugriff:

  ```bash
  /home
    └──<$USER>
        ├── tuxbox
        │   ├── .config
        │   ├── .data
        │   ├── bin
        │   └── buildenv
        ├── Archive
        ├── bin
        ├── sources
        ├── sstate-cache
  ```

## 2.4 Ports konfigurieren

  Der Container stellt einige Zugänge über bestimmte Netzwerkports zur Verfügung. Dies erlaubt den Zugang über einen Webbrowser auf die Buildergebnisse und den Zugang via ssh auf den Container.

### 2.4.1 Webzugriff

  Standardmäßig ist der Container so konfiguriert, dass er auf Port 80 lauscht. Dein Host wird über Port 8080 auf den eingebauten Webserver (`lighttpd`) des Containers gemappt:

  - Port: 8080 (Host) -> 80 (Container)

  Dies ermöglicht den Zugriff via Webserver auf die erzeugten Images und Pakete (ipk's). Set-Top Boxen können damit direkt Updates beispielsweise aus deinem Heimnetz abrufen.
  Falls der Port 8080 des Hostsystems bei Dir bereits belegt ist, kannst Du diese Einstellungen entweder in der `docker-compose.yml` Datei anpassen oder beim Starten des Containers angeben. Dies könnte so aussehen, wenn man auf den Port 8081 mappt:

  - 808**1**:80
   
  Einstellungen am Webserver können in der zuständigen lighttpd-Konfugarionsdatei vorgenommen werden, welche im entsprechenden Volume zur Verfügung steht:

  ```bash
   ~/tuxbox
     └──.config
        └── lighttpd
            └── lighttpd.conf
  ```
  In der `lighttpd.conf` ist `dir-listing` aktiviert, so dass man ohne zusätzlichen Content auskommt.
  
  ```bash
  ~/tuxbox/config/lighttpd$ cat lighttpd.conf
  ...
  #server.compat-module-load   = "disable"
  server.modules += (
        "mod_dirlisting",
        "mod_staticfile",
  )
  dir-listing.activate = "enable"
 ```
 
### 2.4.2 SSH

  Üblicherweise greift man auf den Container direkt über `docker exec` zu.
  Der Container stellt auch einen ssh-Server zur Verfügung. Der ssh-Server ist standardmäßig so konfiguriert:

   - Port: 222 (Host) -> 22 (Container)
   - Passwort: = Benutzername (wie in .env festgelegt)

  Falls der Port 222 auf deinem Hostsystem bereits belegt wäre, kannst Du diese Einstellungen ebenso wie beim Webserver in der `docker-compose.yml` Datei anpassen oder beim Starten des Containers angeben.
   
  Einloggen vom Host-System selbst:
    
  ```bash
  ssh $USER@localhost -p 222
  ```
  
  Einloggen von anderem Rechner:
    
  ```bash
  ssh <benutzer>@<IP oder Hostname des Rechners auf dem der Container läuft> -p 222
  ```
    
# 3. Container bauen

## 3.1 Beispiel 1
 
  Docker-compose Wrapper ausführen:

   ```bash
   ./docker-compose build
   ```

   **Hinweis:** Das vorangestellte `./` ist hier zu berücksichtigen, da es sich um ein Wrapperscript handelt. Das Wrapper-Script ruft `docker-compose` wie vorgesehen auf, allerdings nachdem automatisch eine `.env`-Datei, wie in  [Schritt 2.2](#22-umgebungsvariablen-konfigurieren) beschrieben ist, erzeugt wurde! Dieses Wrapperscript nimmt alle Parameter an, die für `docker-compose` üblich sind. Es dient lediglich dazu, den Aufwand für die Befehlseingabe zur Erzeugung der Umgebungsvariablen, welche über die generierte `.env`-Datei bereitgestellt werden, zu verringern. 

# 4. Container starten

   ```bash
   docker-compose up -d
   ```

# 5. Container stoppen

   ```bash
   docker-compose down
   ```

# 6. Verwenden des Containers

## 6.1. Einloggen

   Man sollte den Namen oder die Container-ID kennen, um sich einloggen zu können. Führe `docker ps` aus, um zu sehen, welche Container gerade verfügbar sind:

   ```bash
   docker ps
   CONTAINER ID   IMAGE                       COMMAND                  CREATED          STATUS                PORTS                    NAMES
   9d6e0d280a9e   tuxbox-build:latest         "/usr/local/bin/star…"   41 minutes ago   Up 41 minutes         0.0.0.0:8080->80/tcp     tuxbox-build
   ```

   Logge dich wie hier beispielsweise auf den Container mit der `Container-ID`  **9d6e0d280a9e** oder dem `Container Namen` ein:


   ```bash
   docker exec -it --user $USER tuxbox-build bash
   ```
   oder:

   ```bash
   docker exec -it --user $USER <CONTAINER ID> bash
   ```

   Es sollte etwa dieses Prompt erscheinen:

   ```bash
   ~/tuxbox/buildenv$
   ```

  Zuerst solltest Du sicherstellen, dass `buildenv` aktuell ist. Wenn das Dockerimage frisch gebaut wurde, sollte das schon erledigt sein, ansonsten führe deshalb eine Aktualisierung durch:

  ```bash
  ~/tuxbox/buildenv$ git pull -r origin master
  ```

  Ab jetzt kannst Du die Buildumgebung mit dem Container nutzen.

## 6.2. Buildumgebung nutzen

  Nach dem Einloggen in den Container befindest Du dich bereits im Verzeichnis `buildenv`, in welchem sich das Init-Script befindet. Jetzt kannst du wie [hier](https://github.com/tuxbox-neutrino/buildenv/blob/master/README.md) beschrieben fortfahren.

  Die vom Buildsystem erzeugten Images und Pakete werden über persistente Volumes innerhalb deines Home-Verzeichnisses des Hosts verfügbar gemacht. Standardmäßig ist dafür dieser Ort vorgesehen:

  ```bash
  /home
   └──<$USER>
       ├── tuxbox
       :   ├── buildenv
           :   ├── dist
               :
   ```
  **Hinweis:** Solltest Du deine Volumes anders eingerichtet haben, kann dies natürlich abweichen.

  Der Container stellt einen Webserver zur Verfügung und ist lokal und im LAN standardmäßig über den Port 8080 erreichbar:

   - [http://localhost<:PORT-NUMMER>](http://localhost:8080)
   - [http://127.0.0.1<:PORT-NUMMER>](http://127.0.0.1:8080)
   
   oder im LAN

   - [http://IP<:PORT-NUMMER>](http://192.168.1.36:8080)


# 7. Container aktualisieren

  Entsprechend wie unter [Schritt 2.1](#21-repository-klonen-und-in-das-geklonte-repo-wechseln) angegeben, kann das Repository, dass die Rezeptur für den Container enthält, regelmäßig aktualisiert werden.
  Dafür wechselt man in das Repository und führt dieses Kommando aus:

 ```bash
  ~/docker-buildenv$ git pull -r origin master
 ```

 Anschließend wie [hier](#3-container-bauen) beschrieben, den Container neu erstellen lassen.

# 8. Unterstützung

  Für weitere Fragen, Problemen oder Unterstützung öffne ein [Issue im GitHub](https://github.com/dbt1/docker-buildenv/issues) oder melde Dich im [Forum](https://forum.tuxbox-neutrino.org/forum/viewforum.php?f=77).



