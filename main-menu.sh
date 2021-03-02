#!/bin/bash
#functions
#draw menus
draw-main-menu(){
    echo "1) Refresh aliases"
    echo "2) Site Migration"
    echo "3) UUID"
    echo "4) Help"
    echo "5) Quit"
}
draw-site-menu(){
    echo "1) Prod to Test"
    echo "2) Test to Prod"
    echo "3) Prod environment download"
    echo "4) Test environment upload"
    echo "5) Test environment download"
    echo "6) Prod environment upload"
    echo "7) Help"
    echo "8) Quit"

}
draw-uuid-menu(){
    echo "1) All in one"
    echo "2) View UUID"
    echo "3) Generate UUID"
    echo "4) Set UUID"
    echo "5) Help"
    echo "6) Quit"
}
#Script Helpers
    #$1 is $SOURCEALIAS
    #$2 is usually environment
    #$3 is usually command
site-search(){
    read -r -p "Enter the site name to search for: " SITENAME
    echo ""
    echo "==================================================="
    echo "Searching for $SITENAME"
    echo "==================================================="
    echo ""
    drush site:alias | grep $SITENAME
    echo ""
    echo "Copy the site alias between the @ and the environment (.01dev2) for the desired site"
    echo ""
    read -p "Was the site you were looking for found?  Y/N  " -n 1 -r SITEFOUND
    echo ""
    if [[ ! $SITEFOUND =~ ^[Yy]$ ]]
    then
        exit 1
    fi
}
files-download(){
    #$1 reflects the $SOURCEALIAS variable.
    #$2 reflects the environment.  Change the argument in the function scripts seciton for the corresponding environment if needed.
    echo ""
    echo "==================================================="
    echo "Copying files from @$1.01$2 to /tmp/$1/files" 
    echo "==================================================="
    echo ""
    mkdir -p tmp/$1/files
    drush -v rsync @$1.01$2:%files ./tmp/$1/files
}
files-upload(){
    echo ""
    echo "==================================================="
    echo "Uploading files to @$1.01$2"
    echo "==================================================="
    echo ""
    drush -v rsync ./tmp/$1/files/ @$1:%files/
}
acsf-modules(){
    #enable or disable acsf modules
    #$3 "Uninstalling" or "Enabling"
    #$4 pmu (uninstall) or en (enable)
    echo ""
    echo "==================================================="
    echo "$3 ACSF Modules from @$1.01$2"
    echo "==================================================="
    echo ""
    drush @$1.01$2 $4 acsf acsf_sso acsf_sj acsf_variables acsf_duplication acsf_theme
}
acsf-error(){
    read -p "Was there an error that the acsf.settings already exists?  Y/N  " -n 1 -r ACSFERROR
        echo ""
        if [[ ! $ACSFERROR =~ ^[Nn]$ ]]
        then
            drush @$1.01live config:delete acsf.settings
            drush @$1.01live en acsf acsf_sso acsf_sj acsf_variables acsf_duplication acsf_theme
        fi
        echo ""
        echo "Finished"
}
database-download(){
    echo ""
    echo "==================================================="
    echo "Copying database from @$1.01$2"
    echo "==================================================="
    echo ""
    drush @$1.01$2 sql-dump > ./tmp/$1/archive.sql
}
database-drop(){
    echo ""
    echo "==================================================="
    echo "Dropping database from @$1.01$2" 
    echo "==================================================="
    echo ""
    drush @$1.01$2 sql-drop
}
database-upload(){
    echo ""
    echo "==================================================="
    echo "Uploading database from dump to @$1.01$2"
    echo "==================================================="
    echo ""
    drush @$1.01$2 sql-cli < ./tmp/$1/archive.sql
}
cron-run(){
    echo ""
    echo "==================================================="
    echo "Running CRON"
    echo "==================================================="
    echo ""
    drush @$1.01$2 CRON
}
clear-cache(){
    echo ""
    echo "==================================================="
    echo "Clearing cache"
    echo "==================================================="
    echo ""
    drush @$1.01$2 cr
    echo ""
}
#Main Script Functions
refresh(){
    echo "==================================================="
    echo "Updating BLT Aliases"
    echo "==================================================="
    echo ""
    if [ -d ./drush/sites ]
    then 
        rm -r drush/sites
    fi
    ./vendor/bin/blt aliases
    echo "==================================================="
    echo "Updating Site YML Files"
    echo "==================================================="
    echo ""
    find ./drush/sites -type f -exec sed -i "s/ssh: { options: '-p 22' }/ssh: { options: '-p 22', tty: 0 }/g" {} +
}
prod-download(){
    site-search;
    read -r -p "Enter the copied site alias: " SOURCEALIAS;
    files-download $SOURCEALIAS 'live';
    acsf-modules $SOURCEALIAS 'live' 'Uninstalling' 'pmu';
    database-download $SOURCEALIAS 'live';
    acsf-modules $SOURCEALIAS 'live' 'Enabling' 'en';
    acsf-error $SOURCEALIAS;
}
test-upload(){
    site-search;
    read -r -p "Enter the copied site alias: " SOURCEALIAS
    database-drop $SOURCEALIAS 'test';
    database-upload $SOURCEALIAS 'test';
    files-upload $SOURCEALIAS 'test';
    echo ""
    echo "Resetting Modules"
    acsf-modules $SOURCEALIAS 'test' 'Uninstalling' 'pmu';
    acsf-modules $SOURCEALIAS 'test' 'Enabling' 'en';
    cron-run $SOURCEALIAS 'test';
    clear-cache $SOURCEALIAS 'test';    
}
test-download(){
    site-search;
    read -r -p "Enter the copied site alias: " SOURCEALIAS;
    files-download $SOURCEALIAS 'test';
    acsf-modules $SOURCEALIAS 'test' 'Uninstalling' 'pmu';
    database-download $SOURCEALIAS 'test';
    acsf-modules $SOURCEALIAS 'test' 'Enabling' 'en';
    acsf-error $SOURCEALIAS;
}
prod-upload(){
    site-search;
    read -r -p "Enter the copied site alias: " SOURCEALIAS
    database-drop $SOURCEALIAS 'live';
    database-upload $SOURCEALIAS 'live';
    files-upload $SOURCEALIAS 'live';
    echo ""
    echo "Resetting Modules"
    acsf-modules $SOURCEALIAS 'live' 'Uninstalling' 'pmu';
    acsf-modules $SOURCEALIAS 'live' 'Enabling' 'en';
    cron-run $SOURCEALIAS 'live';
    clear-cache $SOURCEALIAS 'live';    

}
#Helper for All in One scripts
check-refresh(){
    read -p "Refresh Site Aliases? Y/N  " -n 1 -r REFRESH
    echo ""
    if [[ $REFRESH =~ ^[Yy]$ ]]
    then
        refresh;
    fi
}
#All in One scripts
prod-to-test(){
    check-refresh;
    prod-download;
    test-upload;
}
test-to-prod(){
    check-refresh;
    test-download;
    prod-upload;
}
#TODO: Minify uuid scripts.  
#TODO: Store first view-uuid as old-uuid.
view-uuid(){
    site-search;
    read -r -p "Enter the copied site alias: " SOURCEALIAS
    echo "PROD"
    PRODuuid=$(drush @$SOURCEALIAS.01live config-get "system.site" uuid) 
    PRODuuid=$(echo "$PRODuuid" | sed 's/^.\{20\}//')
    echo "$PRODuuid"
    echo ""
    echo "TEST"
    TESTuuid=$(drush @$SOURCEALIAS.01test config-get "system.site" uuid)
    echo ""
    TESTuuid=$(echo "$TESTuuid" | sed 's/^.\{20\}//')
    echo "$TESTuuid"
    echo ""
    echo "==================================================="
    echo "Comparing UUIDs"
    echo "==================================================="
    echo ""
    echo "$PRODuuid"
    echo "$TESTuuid"

    if [ "$PRODuuid" != "$TESTuuid" ]
    then
        echo ""
        echo "UUID does not match"
    else
        echo ""
        echo "UUID matches"
    fi
}
generate-uuid(){
    site-search;
    read -r -p "Enter the copied site alias: " SOURCEALIAS
    read -r -p "Prod (live) or Test? " ENV
    case $ENV in
        live|test)
        echo "Environment: $ENV"
        drush @$SOURCEALIAS.01$ENV php-eval "echo \Drupal::service('uuid')->generate();"
        echo "" ;;
        *)
        echo "invalid environment"
        exit 1 ;;
    esac
}
set-uuid(){
    site-search;
    read -r -p "Enter the copied site alias: " SOURCEALIAS
    echo ""
    read -r -p "Enter the generated UUID: " NEWuuid
    echo ""
    echo "==================================================="
    echo "Setting UUID on @$SOURCEALIAS.01live" 
    echo "==================================================="
    echo ""
    drush @$SOURCEALIAS.01live cset system.site uuid $NEWuuid
    echo ""
    echo "==================================================="
    echo "Setting UUID on @$SOURCEALIAS.01test"
    echo "==================================================="
    echo ""
    drush @$SOURCEALIAS.01test cset system.site uuid $NEWuuid
}
uuid-aio(){
    site-search;
    read -r -p "Enter the copied site alias: " SOURCEALIAS  
    echo "==================================================="
    echo "Checking UUIDs"
    echo "==================================================="
    echo ""
    echo "PROD"
    OLDPRODuuid=$(drush @$SOURCEALIAS.01live config-get "system.site" uuid) 
    OLDPRODuuid=$(echo "$OLDPRODuuid" | sed 's/^.\{20\}//')
    echo "$OLDPRODuuid"
    echo ""
    echo "TEST"
    OLDTESTuuid=$(drush @$SOURCEALIAS.01test config-get "system.site" uuid)
    OLDTESTuuid=$(echo "$OLDTESTuuid" | sed 's/^.\{20\}//')
    echo "$OLDTESTuuid"
    echo ""
    echo "==================================================="
    echo "Comparing UUIDs"
    echo "==================================================="
    echo ""
    echo "$OLDPRODuuid"
    echo "$OLDTESTuuid"

    if [ "$PRODuuid" != "$TESTuuid" ]
    then
        echo ""
        echo "UUID does not match"
    else
        echo ""
        echo "UUID matches"
    fi
    read -r -p "Enter the environment to generate the UUID on. (No difference) Prod (live) or Test? " ENV
    case $ENV in
        live|test)
        echo "Environment: $ENV"
        NEWuuid=$(drush @$SOURCEALIAS.01$ENV php-eval "echo \Drupal::service('uuid')->generate();")
        echo "$NEWuuid"
        echo "" ;;
        *)
        echo "invalid environment"
        exit 1 ;;
    esac
    echo ""
    echo "==================================================="
    echo "Setting UUID on @$SOURCEALIAS.01live" 
    echo "==================================================="
    echo ""
    drush @$SOURCEALIAS.01live cset system.site uuid $NEWuuid
    echo ""
    echo "==================================================="
    echo "Setting UUID on @$SOURCEALIAS.01test"
    echo "==================================================="
    echo ""
    drush @$SOURCEALIAS.01test cset system.site uuid $NEWuuid
    echo ""
    echo "==================================================="
    echo "Checking UUIDs"
    echo "==================================================="
    echo ""
    echo "PROD"
    PRODuuid=$(drush @$SOURCEALIAS.01live config-get "system.site" uuid) 
    PRODuuid=$(echo "$PRODuuid" | sed 's/^.\{20\}//')
    echo "$PRODuuid"
    echo ""
    echo "TEST"
    TESTuuid=$(drush @$SOURCEALIAS.01test config-get "system.site" uuid)
    echo ""
    TESTuuid=$(echo "$TESTuuid" | sed 's/^.\{20\}//')
    echo "$TESTuuid"
    echo ""
    echo "==================================================="
    echo "Comparing UUIDs"
    echo "==================================================="
    echo ""
    echo "$PRODuuid"
    echo "$TESTuuid"

    if [ "$PRODuuid" != "$TESTuuid" ]
    then
        echo ""
        echo "UUID does not match"
    else
        echo ""
        echo "UUID matches"
    fi
    echo ""
    echo "==================================================="
    echo "Verify Old and New UUIDs"
    echo "==================================================="
    echo ""
    echo "Old prod UUID: $OLDPRODuuid"
    echo "Old test UUID: $OLDTESTuuid"
    echo "New prod UUID: $PRODuuid"
    echo "New test UUID: $TESTuuid"
    echo ""
}
#site migration menu
site-migration-menu(){
    PS3='Site Migration - Please enter your choice: '
    options=("Prod to Test" "Test to Prod" "Prod environment download" "Test environment upload" "Test environment download" "Prod environment upload" "Help" "Quit")
    select opt in "${options[@]}"
    do
        case $opt in
            "Prod to Test")
                prod-to-test;
                draw-site-menu;
                ;;
            "Test to Prod")
                test-to-prod;
                draw-site-menu;
                ;;
            "Prod environment download")
                prod-download;
                draw-site-menu;
                ;;
            "Test environment upload")
                test-upload;
                draw-site-menu;
                ;;
            "Test environment download")
                test-download;
                draw-site-menu;
                ;;
            "Prod environment upload")
                prod-upload;
                draw-site-menu;
                ;;
            "Help")
                echo ""
                echo "1) Prod to Test - Backup the production environment and migrate to the test environment."
                echo "2) Test to Prod - Backup the test environment and migrate to the production environment."
                echo "3) Prod environment download - Backup the production environment."
                echo "4) Test environment upload - Migrate the backed up production environment to the test environment."
                echo "5) Test environment download - Backup the test environment."
                echo "6) Prod environment upload - Migrate the backed up test environment to the production environment."
                echo "7) Help - Display this text."
                echo "8) Quit - Back to main menu."
                echo ""
                ;;
            "Quit")
                clear
                break
                ;;
            *)  echo "invalid option $REPLY"
                echo ""
                draw-site-menu
                ;;
        esac
    done  
}
#uuid menu
uuid-menu(){
    PS3='UUID - Please enter your choice: '
    options=("All in one" "View UUID" "Generate UUID" "Set UUID" "Help" "Quit")
    select opt in "${options[@]}"
    do
        case $opt in
            "All in one")
                uuid-aio;
                draw-uuid-menu;
                ;;
            "View UUID")
                view-uuid;
                draw-uuid-menu;
                ;;
            "Generate UUID")
                generate-uuid;
                draw-uuid-menu;
                ;;
            "Set UUID")
                set-uuid;
                draw-uuid-menu;
                ;;
            "Help")
                echo ""
                echo "1) UUID All in one - Generate and set a new UUID on both production and test environments, then show the old and new UUID."
                echo "2) View UUID - View the UUID for both production and test environments."
                echo "3) Generate UUID - Generate, but not set, a UUID on either the production or test environment."
                echo "4) Set UUID - Set a specified UUID on both production and test environments."
                echo "5) Help - Display this text."
                echo "6) Quit - Back to main menu."
                ;;
            "Quit")
                clear
                break
                ;;
            *)  echo "invalid option $REPLY"
                echo ""
                draw-uuid-menu
                ;;
        esac
    done  
}
#reset menu
reset-menu(){
    PS3='Please enter your choice: ';
    draw-main-menu;
}


#main operation
PS3='Please enter your choice: '
options=("Refresh aliases" "Site Migration" "UUID" "Help" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Refresh aliases")
            refresh;
            reset-menu
            ;;
        "Site Migration")
            echo "migrate";
            clear
            site-migration-menu;
            reset-menu;
            ;;
        "UUID")
            echo "uuid"
            clear
            uuid-menu;
            reset-menu;
            ;;
        "Help")
            echo ""
            echo "1) Refresh Aliases - Regenerate drush site aliases."
            echo "2) Site Migration - Tools to back up and migrate sites."
            echo "3) UUID - Tools to manage site UUIDs."
            echo "4) Help - Display this text."
            echo "5) Quit - Exit menu."
            ;;
        "Quit")
            exit 1
            ;;
        *)  echo "invalid option $REPLY"
            echo ""
            draw-main-menu
            ;;
    esac
done