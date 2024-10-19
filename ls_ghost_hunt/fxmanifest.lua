fx_version 'cerulean'
games      { 'gta5' }
lua54 'yes'

author 'Robbie | Lith Studios'
description 'Ghost Hunting'
version '1.0.0'


data_file 'DLC_ITYP_REQUEST' 'stream/ls_hunt_camera.ytyp'
--
-- Server
--
shared_scripts {
    'link_check.lua'
}

server_scripts {
    'server/functions.lua',
    "config.lua",
    "server/server.lua",
}
--
-- Client
--

client_scripts {
    "client/functions.lua",
    "config.lua",  
    "client/client.lua",
}

files{
    "stream/*",
}
