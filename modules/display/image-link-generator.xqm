xquery version "3.0";

module namespace image-link-generator="http://hra.uni-heidelberg.de/ns/tamboti/modules/display/image-link-generator";

import module namespace config="http://exist-db.org/mods/config" at "../config.xqm";
import module namespace security="http://exist-db.org/mods/security" at "/db/apps/tamboti/modules/search/security.xqm";

declare namespace vra="http://www.vraweb.org/vracore4.htm";
declare variable $image-link-generator:services := doc("../configuration/services.xml");

declare function image-link-generator:generate-href($image-uuid, $uri-name) {
    if (not($image-uuid)) then
        ()
    else

        let $vra-image := security:get-resource($image-uuid)
        let $image-href := data($vra-image/@href)
        
        (: get image-service :)
        let $image-service-name :=
            if (fn:substring-before($image-href, "://") = "") then
                "local"
            else
                fn:substring-before($image-href, "://")
        
        (: get image service definitons   :)
        let $image-service := $image-link-generator:services//service/image-service[@name=$image-service-name]
        return 
            let $image-service-uri := $image-service/uri[@type="get" and @name=$uri-name]
            return 
                let $image-url := 
                    (: Replace variables with query result :)
                    for $variable at $pos in $image-service-uri//element-query 
                        let $key := data($variable/@key)
                        let $query-string := "$vra-image/" || $variable/text()
                        let $value := xs:string(data(util:eval($query-string)))
                        return
                            if($value) then
                                replace($image-service-uri/url/text(), "\[" || $pos ||"\]" , $value)
                            else 
                                ()
                return
                    $image-url
};
