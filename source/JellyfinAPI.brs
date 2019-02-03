function APIRequest(url as String, params={} as Object)
    req = createObject("roUrlTransfer")

    server = get_var("server")

    if server_is_https() then
        req.setCertificatesFile("common:/certs/ca-bundle.crt")
    end if

    full_url = server + "/emby/" + url
    if params.count() > 0
        full_url = full_url + "?"

        param_array = []
        for each field in params.items()
            if type(field.value) = "String" then
                item = field.key + "=" + req.escape(field.value.trim())
            else if type(field.value) = "roInteger" then
                item = field.key + "=" + req.escape(str(field.value).trim())
            else
                item = field.key + "=" + req.escape(field.value)
            end if
            param_array.push(item)
        end for
        full_url = full_url + param_array.join("&")
    end if

    req.setUrl(full_url)

    req = authorize_request(req)

    return req
end function

function parseRequest(req)
    json = ParseJson(req.GetToString())
    return json
end function

function server_is_https() as Boolean
    server = get_var("server")

    i = server.Instr(":")

    ' No protocol found
    if i = 0 then
        return False
    end if

    protocol = Left(server, i)
    if protocol = "https" then
        return True
    end if
    return False
end function

function get_token(user as String, password as String)
    bytes = createObject("roByteArray")
    bytes.FromAsciiString(password)
    digest = createObject("roEVPDigest")
    digest.setup("sha1")
    hashed_pass = digest.process(bytes)

    url = "Users/AuthenticateByName?format=json"
    req = APIRequest(url)

    ' BrightScript will only return a POST body if you call post asynch
    ' and then wait for the response
    req.setMessagePort(CreateObject("roMessagePort"))
    req.AsyncPostFromString("Username=" + user + "&Password=" + hashed_pass)
    resp = wait(5000, req.GetMessagePort())
    if type(resp) <> "roUrlEvent"
        return invalid
    end if

    json = ParseJson(resp.GetString())

    GetGlobalAA().AddReplace("user_id", json.User.id)
    GetGlobalAA().AddReplace("user_token", json.AccessToken)
    return json
end function

function authorize_request(request)
    auth = "MediaBrowser"
    auth = auth + " Client=" + Chr(34) + "Jellyfin Roku" + Chr(34)
    auth = auth + ", Device=" + Chr(34) + "Roku Model" + Chr(34)
    auth = auth + ", DeviceId=" + Chr(34) + "12345" + Chr(34)
    auth = auth + ", Version=" + Chr(34) + "10.1.0" + Chr(34)

    user = get_var("user_id")
    if user <> invalid and user <> "" then
        auth = auth + ", UserId=" + Chr(34) + user + Chr(34)
    end if

    token = get_var("user_token")
    if token <> invalid and token <> "" then
        auth = auth + ", Token=" + Chr(34) + token + Chr(34)
    end if

    request.AddHeader("X-Emby-Authorization", auth)
    return request
end function


' ServerBrowsing

' List Available Libraries for the current logged in user
' Params: None
' Returns { Items, TotalRecordCount }
function LibraryList()
    url = Substitute("Users/{0}/Views/", get_var("user_id"))
    resp = APIRequest(url)
    return parseRequest(resp)
end function

' Search for a string
' Params: Search Query
' Returns: { SearchHints, TotalRecordCount }
function SearchMedia(query as String)
    resp = APIRequest("Search/Hints", {"searchTerm": query})
    return parseRequest(resp)
end function

' List items from within a Library
' Params: Library ID, Limit, Offset, SortBy, SortOrder, IncludeItemTypes, Fields, EnableImageTypes
' Returns { Items, TotalRecordCount }
function ItemList(library_id=invalid as String)
    url = Substitute("Users/{0}/Items/", get_var("user_id"))
    resp = APIRequest(url, {"parentid": library_id, "limit": 30})
    return parseRequest(resp)
end function

function ItemMetaData(id as String)
    url = Substitute("Users/{0}/Items/{1}", get_var("user_id"), id)
    resp = APIRequest(url)
    return parseRequest(resp)
end function

' Video

function VideoStream(id as String)
    player = createObject("roVideoPlayer")

    server = get_var("server")
    path = Substitute("Videos/{0}/stream.mp4", id)
    player.setUrl(server + "/" + path)
    player = authorize_request(player)

    return player
end function