xquery version "3.0";

(:~
    Handles the actual display of the search result. The pagination jQuery plugin in jquery-utils.js
    will call this query to retrieve the next page of search results.
    
    The query returns a simple table with four columns: 
    1) the number of the current record, 
    2) a link to save the current record in "My Lists", 
    3) the type of resource (represented by an icon), and 
    4) the data to display.
:)

import module namespace config = "http://exist-db.org/mods/config" at "../../../modules/config.xqm";
import module namespace retrieve-mods = "http://exist-db.org/mods/retrieve" at "retrieve-mods.xql";
import module namespace retrieve-vra = "http://exist-db.org/vra/retrieve" at "retrieve-vra.xql";
import module namespace retrieve-tei = "http://exist-db.org/tei/retrieve" at "retrieve-tei.xql";
import module namespace retrieve-wiki = "http://exist-db.org/wiki/retrieve" at "retrieve-wiki.xql";
import module namespace jquery = "http://exist-db.org/xquery/jquery" at "resource:org/exist/xquery/lib/jquery.xql";
import module namespace security = "http://exist-db.org/mods/security" at "../../../modules/search/security.xqm";
import module namespace sharing = "http://exist-db.org/mods/sharing" at "../../../modules/search/sharing.xqm";
import module namespace clean = "http://exist-db.org/xquery/mods/cleanup" at "../../../modules/search/cleanup.xql";
import module namespace kwic = "http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";
import module namespace mods-common = "http://exist-db.org/mods/common" at "mods-common.xql";
import module namespace image-link-generator = "http://hra.uni-heidelberg.de/ns/tamboti/modules/display/image-link-generator" at "../../../modules/display/image-link-generator.xqm";
import module namespace functx = "http://www.functx.com";

declare namespace mods = "http://www.loc.gov/mods/v3";
declare namespace vra = "http://www.vraweb.org/vracore4.htm";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace atom = "http://www.w3.org/2005/Atom";
declare namespace html = "http://www.w3.org/1999/xhtml";
declare namespace bs = "http://exist-db.org/xquery/biblio/session";

declare option exist:serialize "method=xhtml media-type=application/xhtml+xml enforce-xhtml=yes";

declare variable $bs:USER := security:get-user-credential-from-session()[1];
declare variable $bs:USERPASS := security:get-user-credential-from-session()[2];

declare variable $bs:THUMB_SIZE_FOR_GRID := 64;
declare variable $bs:THUMB_SIZE_FOR_GALLERY := 128;
declare variable $bs:THUMB_SIZE_FOR_DETAIL_VIEW := 256;

declare variable $session:error-message-before-link := "An error occurred when displaying this record. In order to have this error fixed, please send us an email identifying the record by clicking on the following link: ";
declare variable $session:error-message-after-link := " Clicking on the link will open your default email client.";
declare variable $session:error-message-href := " mailto:petersen@asia-europe.uni-heidelberg.de?Subject=Tamboti%20Display%20Problem&amp;body=Fix%20display%20of%20record%20";
declare variable $session:error-message-link-text := "Send email.";

declare function bs:collection-is-writable($collection as xs:string) {
    if ($collection eq $config:groups-collection) then
        false()
    else
        security:can-write-collection($collection)
};

declare function bs:get-item-uri($item-id as xs:string) {
    fn:concat(
        request:get-scheme(),
        "://",
        request:get-server-name(),
        if((request:get-scheme() eq "http" and request:get-server-port() eq 80) or (request:get-scheme() eq "https" and request:get-server-port() eq 443))then "" else fn:concat(":", request:get-server-port()),
        
        fn:replace(request:get-uri(), "/exist/([^/]*)/([^/]*)/.*", "/exist/$1/$2"),
        
        (:fn:substring-before(request:get-url(), "/modules"), :)
        "/item/",
        $item-id
    )
};

declare function bs:view-gallery-item($mode as xs:string, $item as element(), $currentPos as xs:int) {
    let $thumbSize := 
        if ($mode eq "gallery") 
        then $bs:THUMB_SIZE_FOR_GALLERY 
        else $bs:THUMB_SIZE_FOR_GRID
    let $list-view := 
        if (namespace-uri($item) eq 'http://www.loc.gov/mods/v3')
        then 
            try {
                retrieve-mods:format-list-view('', $item, '')
            } catch * {
            <td class="error" colspan="2">
            {$session:error-message-before-link} 
            <a href="{$session:error-message-href}{$item/@ID/string()}.">{$session:error-message-link-text}</a>
            {$session:error-message-after-link}
            </td>
            }    
        else
            if (namespace-uri($item) eq 'http://www.vraweb.org/vracore4.htm')
            then 
                try {
                    retrieve-vra:format-list-view('', $item, '')
                } catch * {
                <td class="error" colspan="2">
                {$session:error-message-before-link} 
                <a href="{$session:error-message-href}{$item/*/@id/string()}.">{$session:error-message-link-text}</a>
                {$session:error-message-after-link}
                </td>
                }    
            else
                if (namespace-uri($item) eq 'http://www.tei-c.org/ns/1.0')
                then 
                    try {
                        retrieve-tei:format-list-view('', $item, '', '', '')
                    } catch * {
                    <td class="error" colspan="2">
                    {$session:error-message-before-link} 
                    <a href="{$session:error-message-href}{$item/@xml:id/string()}.">{$session:error-message-link-text}</a>
                    {$session:error-message-after-link}
                    </td>
                    }    
                else
                    if (namespace-uri($item) eq 'http://www.w3.org/2005/Atom')
                    then 
                        try {
                            retrieve-wiki:format-list-view('', $item, '', '', '')
                        } catch * {
                        <td class="error" colspan="2">
                        {$session:error-message-before-link} 
                        <a href="{$session:error-message-href}{$item/@xml:id/string()}.">{$session:error-message-link-text}</a>
                        {$session:error-message-after-link}
                        </td>
                        }
                    else ()
                
        return
            if (namespace-uri($item) eq 'http://www.loc.gov/mods/v3')
            then
                <li class="pagination-item {$mode}" xmlns="http://www.w3.org/1999/xhtml">
                    <span class="pagination-number">{ $currentPos }</span>
                    <div class="icon pagination-toggle" title="{$list-view}">
                        <img class="magnify icon-magnifier" src="theme/images/search.png" title="Click to view full screen image"/>
                        { bs:get-icon($thumbSize, $item, $currentPos) }            
                    </div>
                    {
                        if ($mode eq "gallery") then
                            <span class="mods-gallery">{ $list-view }</span>
                        else
                            ()
                    }
                </li>
            else
                if (namespace-uri($item) eq 'http://www.vraweb.org/vracore4.htm')
                then
                <li class="pagination-item {$mode}" xmlns="http://www.w3.org/1999/xhtml">
                    <span class="pagination-number">{ $currentPos }</span>
                    <div class="icon pagination-toggle" title="{$list-view}">
                        <img class="magnify icon-magnifier" src="theme/images/search.png" title="Click to view full screen image"/>
                        { bs:get-icon($thumbSize, $item, $currentPos) }            
                </div>
                    {
                        if ($mode eq "gallery") then
                            <span class="vra-gallery">{ $list-view }</span>
                        else
                            ()
                    }
                </li>
                else 
                    if (namespace-uri($item) eq 'http://www.tei-c.org/ns/1.0')
                    then
                            <li class="pagination-item {$mode}" xmlns="http://www.w3.org/1999/xhtml">
                        <span class="pagination-number">{ $currentPos }</span>
                        <div class="icon pagination-toggle" title="{$list-view}">
                            <img class="magnify icon-magnifier" src="theme/images/search.png" title="Click to view full screen image"/>
                            { bs:get-icon($thumbSize, $item, $currentPos) }            
                    </div>
                        {
                            if ($mode eq "gallery") then
                                <span class="tei-gallery">{ $list-view }</span>
                            else
                                ()
                        }
                    </li>
                    else ()

};

declare function bs:mods-detail-view-table($item as element(mods:mods), $currentPos as xs:int) {
    let $isWritable := bs:collection-is-writable(util:collection-name($item))
    let $document-uri := document-uri(root($item))
    let $id := concat($document-uri, '#', util:node-id($item))
    let $stored := session:get-attribute("personal-list")
    let $saved := exists($stored//*[@id = $id])
    let $results :=  collection($config:mods-root)//mods:mods[@ID=$item/@ID]/mods:relatedItem
    return
        <tr class="pagination-item detail" xmlns="http://www.w3.org/1999/xhtml">
            <td><input class="search-list-item-checkbox" type="checkbox" data-tamboti-record-id="{$item/@ID}"/></td>
            <td class="pagination-number">{$currentPos}</td>
            <td class="actions-cell">
                <a id="save_{$id}" href="#{$currentPos}" class="save">
                    <img title="{if ($saved) then 'Removes Record from My List' else 'Save Record to My List'}" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                </a>
            </td>
            <td class="magnify detail-type">
            { bs:get-icon($bs:THUMB_SIZE_FOR_DETAIL_VIEW, $item, $currentPos)}
            </td>
            <td style="vertical-align:top;">
               <div id="image-cover-box" > 
                {
                   let $image-return :=
                   for $entry in $results
                         let $image-is-preview := $entry//mods:typeOfResource eq 'still image' and  $entry//mods:url[@access eq 'preview']
                            let $print-image :=
                            if ($image-is-preview)
                            then 
                            (
                                let $image := collection($config:mods-root)//vra:image[@id=data($entry//mods:url)]
                                return 
                                   <p>{local:return-thumbnail-detail-view($image)}</p>
                  
                            )
                            else()
                            
                          return $print-image
                   let $elements := for $element in  $item/node()
                        return  $element
                      
                  return $image-return
                  }
                </div>
            </td>
            
            <td class="detail-xml" style="vertical-align:top;">
                { bs:toolbar($item, $isWritable, $id) }
                <abbr class="unapi-id" title="{bs:get-item-uri($item/@ID)}"></abbr>
                {
                    let $collection := util:collection-name($item)
                    let $collection := functx:replace-first($collection, '/db/', '')
                    let $clean := clean:cleanup($item)
                    return
                        try {
                            retrieve-mods:format-detail-view(string($currentPos), $clean, $collection)
                        } catch * {
                        <td class="error" colspan="2">
                        {$session:error-message-before-link} 
                        <a href="{$session:error-message-href}{$item/@ID/string()}.">{$session:error-message-link-text}</a>
                        {$session:error-message-after-link}
                        </td>
                        }
                
                        (: What is $currentPos used for? :)
                }
            </td>
        </tr>
};

declare function local:basic-get-http($uri,$username,$password) {
  let $credentials := concat($username,":",$password)
  let $credentials := util:string-to-binary($credentials)
  let $headers  := 
    <headers>
      <header name="Authorization" value="Basic {$credentials}"/>
    </headers>
  return httpclient:get(xs:anyURI($uri),false(), $headers)
};

declare function local:return-thumbnail-detail-view($image){
    let $image-uuid := $image/@id
    let $image-thumbnail-href := image-link-generator:generate-href($image-uuid, "tamboti-thumbnail")
    let $image-size1000-href := image-link-generator:generate-href($image-uuid, "tamboti-size1000")
    let $image-size150-href := image-link-generator:generate-href($image-uuid, "tamboti-size150")    
    let $image-url := 
        if ($bs:USER eq "guest") then 
            <img src="{$image-thumbnail-href}" alt="image" class="relatedImage picture"/>
        else 
            <a href="{$image-size1000-href}" target="_blank">
                <img src="{$image-size150-href}" alt="image" class="relatedImage picture zoom"/>
            </a>

    return $image-url
};

declare function local:return-thumbnail-list-view($image){
    let $image-uuid := $image/@id
    let $image-thumbnail-href := image-link-generator:generate-href($image-uuid, "tamboti-thumbnail")
    let $image-size1000-href := image-link-generator:generate-href($image-uuid, "tamboti-size1000")
    let $image-url := 
        if ($bs:USER eq "guest") then
            <img src="{$image-thumbnail-href}" alt="image" class="relatedImage picture"/>
        else 
            <a href="{$image-size1000-href}" target="_blank">
                <img src="{$image-thumbnail-href}" alt="image" class="relatedImage picture zoom"/>
            </a>

    return $image-url
};

declare function bs:vra-detail-view-table($item as element(vra:vra), $currentPos as xs:int) {
    let $isWritable := bs:collection-is-writable(util:collection-name($item))
    let $document-uri := document-uri(root($item))
    let $id := concat($document-uri, '#', util:node-id($item))
    let $id := functx:substring-after-last($id, '/')
    let $id := functx:substring-before-last($id, '.')
    let $type := substring($id, 1, 1)
    let $id-position :=
        if ($type eq 'c')
        then '/vra:collection/@id'
        else 
            if ($type eq 'w')
            then '/vra:work/@id'
            else '/vra:image/@id'
    let $stored := session:get-attribute("personal-list")
    let $saved := exists($stored//*[@id = $id])
    return
        <tr class="pagination-item detail" xmlns="http://www.w3.org/1999/xhtml">
            <td><input class="search-list-item-checkbox" type="checkbox" data-tamboti-record-id="{$item/vra:work/@id}"/></td>
            <td class="pagination-number">{$currentPos}</td>
            <td class="actions-cell">
                <a id="save_{$id}" href="#{$currentPos}" class="save">
                    <img title="{if ($saved) then 'Remove Record from My List' else 'Save Record to My List'}" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                </a>
            </td>
            <td class="detail-type" style="vertical-align:top"><img src="theme/images/image.png" title="Still Image"/></td>
            <td style="vertical-align:top;">
                <div id="image-cover-box"> 
                { 
                   (: relids/refid workaround :)
                    for $rel in $item//vra:relationSet/vra:relation[@type = "imageIs"]
                        let $image-uuid := 
                            if(starts-with(data($rel/@relids), "i_")) then
                                data($rel/@relids)
                            else 
                                if(starts-with(data($rel/@refid), "i_")) then
                                    data($rel/@refid)
                                else
                                    ()
                        let $image := security:get-resource($image-uuid)
                        return
                            <p>{local:return-thumbnail-detail-view($image)}</p>
                }
                </div>
            </td>            
            <td class="detail-xml" style="vertical-align:top;">
                { bs:toolbar($item, $isWritable, $id) }
                <!--Zotero does not import vra records <abbr class="unapi-id" title="{bs:get-item-uri(concat($item, $id-position))}"></abbr>-->
                {
                    let $collection := util:collection-name($item)
                    let $collection := functx:replace-first($collection, '/db/', '')
                    let $clean := clean:cleanup($item)
                    return
                        try {
                            retrieve-vra:format-detail-view(string($currentPos), $clean, $collection, $type, $id)
                        } catch * {
                        <td class="error" colspan="2">
                        {$session:error-message-before-link} 
                        <a href="{$session:error-message-href}{$item/*/@id/string()}.">{$session:error-message-link-text}</a>
                        {$session:error-message-after-link}
                        </td>
                        }                        
                }
            </td>
        </tr>
};

declare function bs:wiki-detail-view-table($item as element(), $currentPos as xs:int) {
    let $isWritable := bs:collection-is-writable(util:collection-name($item))
    let $id := concat(document-uri(root($item)), '#', util:node-id($item))
    let $id := functx:substring-after-last($id, '/')
    let $id := functx:substring-before-last($id, '.')
    let $type := substring($id, 1, 1)
    let $id-position :=
        if ($type eq 'c')
        then '/vra:collection/@id'
        else 
            if ($type eq 'w')
            then '/vra:work/@id'
            else '/vra:image/@id'
    let $stored := session:get-attribute("personal-list")
    let $saved := exists($stored//*[@id = $id])
    let $vra-work := security:get-resource($id)/vra:relationSet/vra:relation
    
    return
        <tr class="pagination-item detail" xmlns="http://www.w3.org/1999/xhtml">
            <td class="pagination-number">{$currentPos}</td>
            <td class="actions-cell">
                <a id="save_{$id}" href="#{$currentPos}" class="save">
                    <img title="{if ($saved) then 'Remove Record from My List' else 'Save Record to My List'}" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                </a>
            </td>
            <td class="detail-type" style="vertical-align:top"><img src="theme/images/image.png" title="Still Image"/></td>
            <td style="vertical-align:top;">
                <div id="image-cover-box"> 
                { 
                    if ($vra-work)
                    then
                        (: relids/refid workaround :)
                        for $rel in $vra-work/vra:relationSet/vra:relation
                            let $image-uuid := 
                                if(starts-with(data($rel/@refid), "i_")) then
                                    data($rel/@refid)
                                else 
                                    data($rel/@relids)
                            let $image := security:get-resource($image-uuid)
                            return
                                <p>{local:return-thumbnail-detail-view($image)}</p>
                    else 
                        let $image := collection($config:mods-root)//vra:image[@id=$id]
                        return
                            <p>{local:return-thumbnail-detail-view($image)}</p>
                     (: 
                     return <img src="{concat(request:get-scheme(),'://',request:get-server-name(),':',request:get-server-port(),request:get-context-path(),'/rest', util:collection-name($image),"/" ,$image-name)}"  width="200px"/>
                     :)               
                }
                </div>
            </td>            
            <td class="detail-xml" style="vertical-align:top;">
                { bs:toolbar($item, $isWritable, $id) }
                <!--Zotero does not import vra records <abbr class="unapi-id" title="{bs:get-item-uri(concat($item, $id-position))}"></abbr>-->
                {
                    let $collection := util:collection-name($item)
                    return
                        try {
                            retrieve-wiki:format-detail-view(string($currentPos), $item, $collection, $type, $id)
                        } catch * {
                        <td class="error" colspan="2">
                        {$session:error-message-before-link} 
                        <a href="{$session:error-message-href}{$item/@xml:id/string()}.">{$session:error-message-link-text}</a>
                        {$session:error-message-after-link}
                        </td>
                        }
                }
            </td>
        </tr>
};

declare function bs:tei-detail-view-table($item as element(), $currentPos as xs:int) {
    let $isWritable := bs:collection-is-writable(util:collection-name($item))
    let $document-uri  := document-uri(root($item))
    let $node-id := util:node-id($item)
    let $id := concat(document-uri(root($item)), '#', util:node-id($item))
    let $id := functx:substring-after-last($id, '/')
    let $id := functx:substring-before-last($id, '.')
    let $type := substring($id, 1, 1)
    let $stored := session:get-attribute("personal-list")
    let $saved := exists($stored//*[@id = $id])

    return
        <tr class="pagination-item detail" xmlns="http://www.w3.org/1999/xhtml">
            <td><input class="search-list-item-checkbox" type="checkbox" data-tamboti-record-id="{$item/@id}"/></td>
            <td class="pagination-number">{$currentPos}</td>
            <td class="actions-cell">
                <a id="save_{$id}" href="#{$currentPos}" class="save">
                    <img title="{if ($saved) then 'Remove Record from My List' else 'Save Record to My List'}" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                </a>
            </td>
            <td class="detail-xml">
                { bs:toolbar($item, $isWritable, $id) }
                <!--NB: why is this phoney HTML tag used to anchor the Zotero unIPA?-->
                <!--Zotero does not import tei records <abbr class="unapi-id" title="{bs:get-item-uri(concat($item, $id-position))}"></abbr>-->
                {
                    let $collection := util:collection-name($item)
                    let $collection := functx:replace-first($collection, '/db/', '')
                    let $clean := clean:cleanup($item)
                    return
                        try {
                            retrieve-tei:format-detail-view(string($currentPos), $clean, $collection, $document-uri, $node-id)
                        } catch * {
                        <td class="error" colspan="2">
                        {$session:error-message-before-link} 
                        <a href="{$session:error-message-href}{$item/@xml:id/string()}.">{$session:error-message-link-text}</a>
                        {$session:error-message-after-link}
                        </td>
                        }
                }
            </td>
        </tr>
};

declare function bs:mods-list-view-table($item as node(), $currentPos as xs:int) {
    let $id := concat(document-uri(root($item)), '#', util:node-id($item))
    let $stored := session:get-attribute("personal-list")
    let $saved := exists($stored//*[@id = $id])
    return
        <tr xmlns="http://www.w3.org/1999/xhtml" class="pagination-item list">
            <td><input class="search-list-item-checkbox" type="checkbox" data-tamboti-record-id="{$item/@ID}"/></td>
            <td class="pagination-number">{$currentPos}</td>
            {
            <td class="actions-cell">
                <a id="save_{$id}" href="#{$currentPos}" class="save">
                    <img title="{if ($saved) then 'Remove Record from My List' else 'Save Record to My List'}" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                </a>
            </td>
            }
            <td class="list-type icon magnify">
            { bs:get-icon($bs:THUMB_SIZE_FOR_GALLERY, $item, $currentPos)}
            </td>
            <td/>
            {
            <td class="pagination-toggle">
                <abbr class="unapi-id" title="{bs:get-item-uri($item/@ID)}"></abbr>
                <a>
                {
                    let $collection := util:collection-name($item)
                    let $collection := functx:replace-first($collection, '/db/', '')
                    let $clean := clean:cleanup($item)
                    return
                        try {
                            retrieve-mods:format-list-view(string($currentPos), $clean, $collection)
                        } catch * {
                        <td class="error" colspan="2">
                        {$session:error-message-before-link} 
                        <a href="{$session:error-message-href}{$item/@ID/string()}.">{$session:error-message-link-text}</a>
                        {$session:error-message-after-link}
                        </td>
                        }                        
                        (: Originally $item was passed to retrieve-mods:format-list-view() - was there a reason for that? Performance? :)
                }
                </a>
            </td>
            }
        </tr>
};

declare function bs:vra-list-view-table($item as node(), $currentPos as xs:int) {
    let $id := concat(document-uri(root($item)), '#', util:node-id($item))
    let $id := functx:substring-after-last($id, '/')
    let $id := functx:substring-before-last($id, '.')
    let $type := substring($id, 1, 1)
    let $id-position :=
        if ($type eq 'c')
        then '/vra:collection/@id'
        else 
            if ($type eq 'w')
            then '/vra:work/@id'
            else '/vra:image/@id'
    let $stored := session:get-attribute("personal-list")
    let $saved := exists($stored//*[@id eq $id])
        return
            <tr xmlns="http://www.w3.org/1999/xhtml" class="pagination-item list">
                <td><input class="search-list-item-checkbox" type="checkbox" data-tamboti-record-id="{$item/vra:work/@id}"/></td>
                <td class="pagination-number" style="vertical-align:middle">{$currentPos}</td>
                {
                <td class="actions-cell" style="vertical-align:middle">
                    <a id="save_{$id}" href="#{$currentPos}" class="save">
                        <img title="{if ($saved) then 'Remove Record from My List' else 'Save Record to My List'}" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                    </a>
                </td>
                }
                <td class="list-type" style="vertical-align:middle"><img src="theme/images/image.png" title="Still Image"/></td>
                { 
                    (: relids/refid workaround :)
                    let $relations := 
                        if (exists($item//vra:relation[@type="imageIs" and @pref="true"])) then 
                            $item//vra:relation[@type="imageIs" and @pref="true"]
                        else
                            $item//vra:relation[@type="imageIs"]
                    let $relids :=
                        for $rel in $relations
                            let $image-uuid := 
                                if(starts-with(data($rel/@refid), "i_")) then
                                    data($rel/@refid)
                                    else 
                                        data($rel/@relids)
                                return $image-uuid 
                    (:NB: relids can hold multiple values; the image record with @pref on vra:relation is "true".
                    For now, we disregard this; otherwise we have to check after retrieving the image records.:)
                    let $relids := tokenize($relids, ' ')

                    (: Elevate rights because user is not able to search whole $config:mods-root   :)
                    (: ToDo: do not search whole $config:mods-root, since we know the image-record is in VRA_images/ relative to work record  :)
                    let $image := 
                        system:as-user($config:dba-credentials[1], $config:dba-credentials[2], 
                            collection($config:mods-root)//vra:image[@id = $relids]
                        )

                    return
                        <td class="list-image">{local:return-thumbnail-list-view($image)}</td>               
                }
                {
                <td class="pagination-toggle" style="vertical-align:middle">
                    <!--Zotero does not import vra records <abbr class="unapi-id" title="{bs:get-item-uri(concat($item, $id-position))}"></abbr>-->
                    <a>
                    {
                        let $collection := util:collection-name($item)
                        let $collection := functx:replace-first($collection, '/db/', '')
                        let $clean := clean:cleanup($item)
                        return
                        try {
                            retrieve-vra:format-list-view(string($currentPos), $clean, $collection)
                        } catch * {
                        <td class="error" colspan="2">
                        {$session:error-message-before-link} 
                        <a href="{$session:error-message-href}{$item/*/@id/string()}.">{$session:error-message-link-text}</a>
                        {$session:error-message-after-link}
                        </td>
                        }
                    }
                    </a>
                </td>
                }
            </tr>
};

declare function bs:tei-list-view-table($item as node(), $currentPos as xs:int) {
    let $document-uri  := document-uri(root($item))
    let $node-id := util:node-id($item)
    let $id := concat($document-uri, '#', $node-id)
    let $id := functx:substring-after-last($id, '/')
    let $id := functx:substring-before-last($id, '.')
    let $type := substring($id, 1, 1)
    let $stored := session:get-attribute("personal-list")
    let $saved := exists($stored//*[@id = $id])
    return
        <tr xmlns="http://www.w3.org/1999/xhtml" class="pagination-item list">
            <td><input class="search-list-item-checkbox" type="checkbox" data-tamboti-record-id="{document-uri(root($item))}"/></td>        
            <td class="pagination-number">{$currentPos}</td>
            {
            <td class="actions-cell">
                <a id="save_{$id}" href="#{$currentPos}" class="save">
                    <img title="{if ($saved) then 'Remove Record from My List' else 'Save Record to My List'}" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                </a>
            </td>
            }
            <td class="list-type icon magnify">
            { bs:get-icon($bs:THUMB_SIZE_FOR_GALLERY, $item, $currentPos)}
            </td>
            <td/>
            {
            <td class="pagination-toggle">
                <!--Zotero does not import tei records <abbr class="unapi-id" title="{bs:get-item-uri(concat($item, $id-position))}"></abbr>-->
                <a>
                {
                    let $collection := util:collection-name($item)
                    let $collection := functx:replace-first($collection, '/db/', '')
                    (:let $clean := clean:cleanup($item):)
                    return
                        try {
                            retrieve-tei:format-list-view(string($currentPos), $item, $collection, $document-uri, $node-id)
                        } catch * {
                        <td class="error" colspan="2">
                        {$session:error-message-before-link} 
                        <a href="{$session:error-message-href}{$item/@xml:id/string()}.">{$session:error-message-link-text}</a>
                        {$session:error-message-after-link}
                        </td>
                        }
                }
                </a>
            </td>
            }
        </tr>
};

declare function bs:wiki-list-view-table($item as node(), $currentPos as xs:int) {
    let $document-uri  := document-uri(root($item))
    let $node-id := util:node-id($item)
    let $id := concat($document-uri, '#', $node-id)
    let $id := functx:substring-after-last($id, '/')
    let $id := functx:substring-before-last($id, '.')
    let $type := substring($id, 1, 1)
    let $stored := session:get-attribute("personal-list")
    let $saved := exists($stored//*[@id = $id])
    return
        <tr xmlns="http://www.w3.org/1999/xhtml" class="pagination-item list">
            <td><input class="search-list-item-checkbox" type="checkbox" data-tamboti-record-id="{$item/@id}"/></td>
            <td class="pagination-number">{$currentPos}</td>
            {
            <td class="actions-cell">
                <a id="save_{$id}" href="#{$currentPos}" class="save">
                    <img title="{if ($saved) then 'Remove Record from My List' else 'Save Record to My List'}" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                </a>
            </td>
            }
            <td class="list-type icon magnify">
            { bs:get-icon($bs:THUMB_SIZE_FOR_GALLERY, $item, $currentPos)}
            </td>
            <td/>
            {
            <td class="pagination-toggle">
                <!--Zotero does not import tei records <abbr class="unapi-id" title="{bs:get-item-uri(concat($item, $id-position))}"></abbr>-->
                <a>
                {
                    let $collection := util:collection-name($item)
                    let $collection := functx:replace-first($collection, '/db/', '')
                    (:let $clean := clean:cleanup($item):)
                    return
                        try {
                            retrieve-wiki:format-list-view(string($currentPos), $item, $collection, $document-uri, $node-id)
                        } catch * {
                        <td class="error" colspan="2">
                        {$session:error-message-before-link} 
                        <a href="{$session:error-message-href}{$item/@xml:id/string()}.">{$session:error-message-link-text}</a>
                        {$session:error-message-after-link}
                        </td>
                        }
                }
                </a>
            </td>
            }
        </tr>
};

(:This is the default which gets called if bs:list-view-table() does not know how to handle what is passed to it.:)
(:It is not used at the moment.:)
declare function bs:plain-list-view-table($item as node(), $currentPos as xs:int) {
    let $kwic := kwic:summarize($item, <config xmlns="" width="40"/>)
    let $id := concat(document-uri(root($item)), '#', util:node-id($item))
    let $stored := session:get-attribute("personal-list")
    let $saved := exists($stored//*[@id = $id])
    (:NB: This gives NEP 2013-03-16, but Wolfgang has a fix. :)
    let $titleField := ft:get-field($item/@uri, "Title")
    let $title := if ($titleField) then $titleField else replace($item/@uri, "^.*/([^/]+)$", "$1")
    let $clean := clean:cleanup($item)
    let $collection := util:collection-name($item)
    let $collection-short := functx:replace-first($collection, '/db/', '')
    return
        <tr xmlns="http://www.w3.org/1999/xhtml" class="pagination-item list">
            <td class="pagination-number">{$currentPos}</td>
            {
            <td class="actions-cell">
                <a id="save_{$id}" href="#{$currentPos}" class="save">
                    <img title="Save Record to My List" src="theme/images/{if ($saved) then 'disk_gew.gif' else 'disk.gif'}" class="{if ($saved) then 'stored' else ''}"/>
                </a>
            </td>
            }
            <td class="list-type">
                <a href="{substring($item/@uri, 2)}" target="_new">
                { bs:get-icon($bs:THUMB_SIZE_FOR_GALLERY, $item, $currentPos)}
                </a>
            </td>
            {
            <td class="pagination-toggle">
                <span>{
                        try {
                            retrieve-mods:format-list-view(string($currentPos), $clean, $collection-short)
                        } catch * {
                        <td class="error" colspan="2">
                        {$session:error-message-before-link} 
                        <a href="{$session:error-message-href}{$item/@ID/string()}.">{$session:error-message-link-text}</a>
                        {$session:error-message-after-link}
                        </td>
                        }
                }</span>
                <h4>{$title}</h4>
                { $kwic }
            </td>
            }
        </tr>
};

(:NB: If an element is returned which is not covered by this typeswitch, the following error occurs, i.e. it defaults to kwic:summarize():
the actual cardinality for parameter 1 does not match the cardinality declared in the function's signature: kwic:summarize($hit as element(), $config as element()) element()*. Expected cardinality: exactly one, got 0. [at line 349, column 34, source: /db/apps/tamboti/themes/default/modules/session.xql]
:)
(:NB: each element checked for here should appear in bs:view-table(), otherwise the detail view will show the list view.:)
declare function bs:list-view-table($item as node(), $currentPos as xs:int) {
    typeswitch ($item)
        case element(mods:mods) return
            bs:mods-list-view-table($item, $currentPos)
        case element(vra:vra) return
            bs:vra-list-view-table($item, $currentPos)
        case element(tei:person) return
            bs:tei-list-view-table($item, $currentPos)
        case element(tei:p) return
            bs:tei-list-view-table($item, $currentPos)
        case element(tei:term) return
            bs:tei-list-view-table($item, $currentPos)
        case element(tei:head) return
            bs:tei-list-view-table($item, $currentPos)
        case element(tei:TEI) return
            bs:tei-list-view-table($item, $currentPos)
        case element(tei:bibl) return
            bs:tei-list-view-table($item, $currentPos)
        case element(tei:titleStmt) return
            bs:tei-list-view-table($item, $currentPos)
        case element(atom:entry) return
            bs:wiki-list-view-table($item, $currentPos)
        default return
            bs:plain-list-view-table($item, $currentPos)
};

declare function bs:toolbar($item as element(), $isWritable as xs:boolean, $id as xs:string) {
    let $home := security:get-home-collection-uri($bs:USER)
    (:determine for image record:)
   

    let $collection := util:collection-name($item)
    let $id := 
        if (name($item) eq 'mods') 
        then $item/@ID 
        else
            if (exists($item/vra:work))
            then $item/vra:work/@id
            else ()
    let $imageId :=  
        (: relids/refid workaround :)
        if (exists($item/vra:work)) then
            let $rel :=
                if (exists($item/vra:work/vra:relationSet/vra:relation/@pref[.='true'])) then 
                    $item/vra:work/vra:relationSet/vra:relation[@pref='true']
                else 
                    $item/vra:work/vra:relationSet/vra:relation[1]
            return
                if(starts-with(data($rel/@refid), "i_")) then
                    data($rel/@refid)
                else 
                    data($rel/@relids)
        else $item/vra:image/@id

    let $workdir := if (contains($collection, 'VRA_images')) then (  functx:substring-before-last($collection, "/")) else ($collection)
    let $workdir := if (ends-with($workdir,'/')) then ($workdir) else ($workdir || '/')
    let $imagepath := $workdir || 'VRA_images/' || $imageId || ".xml"
    
    return
        <div class="actions-toolbar">{
            if (name($item) = ('mods', 'vra'))
            then
               <a target="_new" href="source.xql?id={$id}&amp;clean=yes">
                    <img title="View XML Source of Record" src="theme/images/script_code.png"/>
                </a>
            else ()
            }
            {
                (: if the item's collection is writable, display edit/delete and move buttons :)
                if ($isWritable) 
                then
                    (
                        if (xmldb:collection-available("/db/apps/ziziphus/") and name($item) eq 'vra')
                        then
                            <a target="_new" href="/exist/apps/ziziphus/record.xql?id={$id}&amp;workdir={$workdir}&amp;imagepath={$imagepath}">
                                <img title="Edit VRA Record" src="theme/images/page_edit.png"/>
                            </a>
                        else 
                            if (name($item) eq 'mods')
                            then
                                <a href="../edit/edit.xq?id={$item/@ID}&amp;collection={util:collection-name($item)}&amp;type={$item/mods:extension/*:template}">
                                    <img title="Edit MODS Record" src="theme/images/page_edit.png"/>
                                </a>
                            else ()
                        ,
                        <a class="remove-resource" href="#{$id}"><img title="Delete Record" src="theme/images/delete.png"/></a>
                        ,
                        <a class="move-resource" href="#{$id}"><img title="Move Record" src="theme/images/shape_move_front.png"/></a>
                        ,
                        if (not($item/vra:image/@id)) then
                            <a class="upload-file-style" directory="false" href="#{$id}" onclick="updateAttachmentDialog">
                                <img title="Upload Attachment" src="theme/images/database_add.png" />
                            </a>
                        else ()                       
                    )
                else
                    ()
            }
            {
                (: button to add a related item :)
                if ($bs:USER ne "guest") 
                then
                    if (name($item) eq 'mods')
                    then
                        <a class="add-related" href="#{if ($isWritable) then $collection else $home}#{$item/@ID}">
                            <img title="Create Related MODS Record" src="theme/images/page_add.png"/>
                        </a>
                    else ()
                else ()
            }
        </div>
};

declare function bs:get-icon-from-folder($size as xs:int, $collection as xs:string) {
    let $thumb := xmldb:get-child-resources($collection)[1]
    let $imgLink := concat(substring-after($collection, "/db"), "/", $thumb)
    return
        <img src="images/{$imgLink}?s={$size}"/>
};

(:~
    Get the preview icon for a linked image resource or get the thumbnail showing the resource type.
:)
declare function bs:get-icon($size as xs:int, $item, $currentPos as xs:int) {
    let $image-url :=
    (: NB: Refine criteria for existence of image:)
        ( 
            $item/mods:location/mods:url[@access="preview"]/string(), 
            $item/mods:location/mods:url[@displayLabel="Path to Folder"]/string() 
        )[1]
    let $type := $item/mods:typeOfResource[1]/string()
    let $hint := 
        if ($type)
        then functx:capitalize-first($type)
        else
            if (in-scope-prefixes($item) = 'xml')
            then 'Unknown Type'
            else 'Extracted Text'
    return
        if (string-length($image-url)) 
        (: Only run if there actually is a URL:)
        (: NB: It should be checked if the URL leads to an image described in the record:)
        then
            let $image-path := concat(util:collection-name($item), "/", $image-url)
            return
                if (collection($image-path)) 
                then bs:get-icon-from-folder($size, $image-path)
                else
                    let $imgLink := concat(substring-after(util:collection-name($item), "/db"), "/", $image-url)
                    return
                        <img title="{$hint}" src="images/{$imgLink}?s={$size}"/>        
        else
        (: For non-image records:)
            let $type := 
                (: If there is a typeOfResource, render the icon for it. :)
                if ($type)
                (: Remove spaces and commas from the image name:)
                then translate(translate($type,' ','_'),',','')
                else
                    (: If there is no typeOfResource, but the resource is XML, render the default icon for it. :)
                    if (in-scope-prefixes($item) = 'xml')
                    then 'shape_square'
                    (: Otherwise it is non-XML contents extracted from a document by tika. This could be a PDF, a Word document, etc. :) 
                    else 'text-x-changelog'
            return 
                <img title="{$hint}" src="theme/images/{$type}.png"/>
};

declare function bs:view-table($cached as item()*, $stored as item()*, $start as xs:int, 
    $count as xs:int, $available as xs:int) {
    <table xmlns="http://www.w3.org/1999/xhtml">
    {
        for $item at $pos in subsequence($cached, $start, $available)
        let $currentPos := $start + $pos - 1
        return
            if ($count eq 1 and $item instance of element(mods:mods)) 
            then bs:mods-detail-view-table($item, $currentPos)
            else
                if ($count eq 1 and $item instance of element(vra:vra)) 
                then bs:vra-detail-view-table($item, $currentPos)
                else 
                    if ($count eq 1 and $item instance of element(tei:TEI)) 
                    then bs:list-view-table($item, $currentPos)
                    else
                        if ($count eq 1 and $item instance of element(tei:person)) 
                        then bs:tei-detail-view-table($item, $currentPos)
                        else
                            if ($count eq 1 and $item instance of element(tei:p)) 
                            then bs:tei-detail-view-table($item, $currentPos)
                            else
                                if ($count eq 1 and $item instance of element(tei:term)) 
                                then bs:tei-detail-view-table($item, $currentPos)
                                else
                                    if ($count eq 1 and $item instance of element(tei:head)) 
                                    then bs:tei-detail-view-table($item, $currentPos)
                                    else
                                        if ($count eq 1 and $item instance of element(tei:bibl)) 
                                        then bs:tei-detail-view-table($item, $currentPos)
                                        else
                                            if ($count eq 1 and $item instance of element(atom:entry)) 
                                            then bs:wiki-detail-view-table($item, $currentPos)
                                            else bs:list-view-table($item, $currentPos)
    }
    </table>
};

declare function bs:view-gallery($mode as xs:string, $cached as item()*, $stored as item()*, $start as xs:int, 
    $count as xs:int, $available as xs:int) {
    <ul xmlns="http://www.w3.org/1999/xhtml">
    {
        for $item at $pos in subsequence($cached, $start, $available)
        let $currentPos := $start + $pos - 1
        (: Why does $currentPos have a final "."? Should be removed. :)
        return
            bs:view-gallery-item($mode, $item, $currentPos)
    }
    </ul>
};

declare function bs:view-all($cached as item()*) {
    let $result := 
        for $resource in $cached
        return
            typeswitch ($resource)
                case element(mods:mods) return data($resource/@ID)
                case element(vra:vra) return data($resource/vra:work/@id)
                default return ()
    return
        (
            "{&quot;"
            ,
            string-join($result, "&quot;: 1, &quot;")
            ,
            "&quot;: 1}"
        )
};

(:~
    Main function: retrieves query results from session cache and
    checks which display mode to use.
:)

 declare function bs:get-resource($start as xs:int, $count as xs:int){
 
  let $resouce := session:get-attribute("mods:cached")
 
  return $resouce
 };
 
 
declare function bs:retrieve($start as xs:int, $count as xs:int) {
    let $mode := request:get-parameter("mode", "gallery")
    let $cached := session:get-attribute("mods:cached")
    let $stored := session:get-attribute("personal-list")    
    let $total := count($cached)
    let $available :=
        if ($start + $count gt $total) then
            $total - $start + 1
        else
            $count
    return
        (: A single entry is always shown in table view for now :)
        if ($mode eq "ajax" and $count eq 1) 
        then bs:view-table($cached, $stored, $start, $count, $available)
        else
            switch ($mode)
                case "gallery" return
                    bs:view-gallery($mode, $cached, $stored, $start, $count, $available)
                case "grid" return
                    bs:view-gallery($mode, $cached, $stored, $start, $count, $available)
                case "multiple-selection" return
                    bs:view-all($cached)
                default return
                    bs:view-table($cached, $stored, $start, $count, $available)
};

session:create(),
let $start := request:get-parameter("start", ())
let $start := xs:int(if ($start) then $start else 1)
let $count := request:get-parameter("count", ())
let $count := xs:int(if ($count) then $count else 10)
return
    bs:retrieve($start, $count)
