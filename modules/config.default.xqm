xquery version "3.0";

module namespace config = "http://exist-db.org/mods/config";

(: 
    Determine the application root collection from the current module load path.
:)
declare variable $config:app-root := 
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    return
        substring-before($modulePath, "/modules")
;

declare variable $config:app-id := "tamboti";

(: this will replace $config:app-id when theming will be solved :)
declare variable $config:actual-app-id := "tamboti";
declare variable $config:app-version := "";

(:~ Biblio security - admin user and users group :)
declare variable $config:biblio-admin-user := "editor";
declare variable $config:biblio-users-group := "biblio.users";
declare variable $config:users-login-blacklist := ("admin", "guest", "SYSTEM");

(:~ Various permissions :)
declare variable $config:resource-mode := "rw-------";
declare variable $config:collection-mode := "rwx------";
declare variable $config:temp-collection-mode := "rwxrws---";
declare variable $config:temp-resource-mode := "rwx------";
declare variable $config:index-collection-mode := "rwxr-xr-x";

declare variable $config:data-collection-name := "resources";
declare variable $config:content-root := "/" || $config:data-collection-name;
declare variable $config:mods-root := "/" || $config:data-collection-name;
declare variable $config:mods-commons := fn:concat($config:mods-root, "/commons");
declare variable $config:users-collection := xs:anyURI(fn:concat($config:mods-root, "/users"));
declare variable $config:mods-root-minus-temp := ($config:mods-commons, $config:users-collection);

declare variable $config:url-image-size := "256";

declare variable $config:search-app-root := concat($config:app-root, "/modules/search");
declare variable $config:edit-app-root := concat($config:app-root, "/modules/edit");

declare variable $config:force-lower-case-usernames as xs:boolean := true();
declare variable $config:enforced-realm-id := "ldap-server.yourdomain.com";

declare variable $config:groups-collection := fn:concat($config:mods-root, "/groups");

declare variable $config:mods-temp-collection := $config:mods-root || "/temp";
declare variable $config:mads-collection := "/db/" || $config:mods-root || "/mads";

declare variable $config:themes := concat($config:app-root, "/themes");
declare variable $config:theme-config := concat($config:themes, "/configuration.xml");

declare variable $config:resources := concat($config:app-root, "/resources");
declare variable $config:images := concat($config:app-root, $config:mods-root ||  "/images");

declare variable $config:images-subcollection := ("VRA_images");


(: If the user has not specified a query, should he see the entire collection contents?
 : Set to true() if a query must be specified, false() to list the entire collection.
 : On large databases, false() will most likely lead to problems.
 :)
declare variable $config:require-query := true();

(: email invitation settings :)
declare variable $config:send-notification-emails := false();
declare variable $config:smtp-server := "smtp.yourdomain.com";
declare variable $config:smtp-from-address := "exist@yourdomain.com";

(:~ Credentials for the dba admin user :)
declare variable $config:dba-credentials := ("admin", "");

declare variable $config:allow-origin := "";

(:~ 
: Function hook which allows you to modify the username of the user
: before they are authenticated.
: Allows you to force a realm id etc.
: 
: @param username The username as entered by the user
: @return the modified username which will be used for authentication
:)
declare function config:rewrite-username($username as xs:string) as xs:string {
    
    let $username := 
        if ($config:force-lower-case-usernames) then
            fn:lower-case($username)
        else
            $username
    return
        (: if @ad is spared in login formular, check if ad user exists and concat @ with ldap-real, if not use $username without  :)
        if (not(fn:contains($username, "@")) and xmldb:exists-user($username || "@" || $config:enforced-realm-id)) then
            $username || "@" || $config:enforced-realm-id
        else
            $username
};

declare variable $config:max-inactive-interval-in-minutes := 480;
