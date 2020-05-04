EM_MigrateProject Macro README

Overview
The EM_MigrateProject macro prepares SAS Enterprise Miner project files for movement to another system and restores prepared project files to a usable form on the new system. Applicable scenarios include:
* Windows <-> UNIX
* UNIX a <-> UNIX b
* 32bit <-> 64bit systems

System Requirements
Enterprise Miner 6.1 M2 or later
SAS v9.2 M3 (TS2M3) and SAS v9.3 or later

Installation Instructions
Unpack the download package to a location or locations accessible from the system on which your projects were created and the system to which you wish to move them.

Using the Software
1. Read the EM_MigrateProject Macro Users Guide from the download package.
2. Backup your original projects before starting the migration process.
3. Run the EM_MigrateProject macro to prepare the project for movement.
4. Move the prepared folders and files to the new system.
5. Setup libnames for all external data for the project.
6. Run the EM_MigrateProject macro to restore the project.
7. If you have migrated your project metadata using the SAS Migration Utility your project migration is complete. If not, on the new system use Enterprise Miner to create a new project from the restored folders and files to rebuild the project metadata.
