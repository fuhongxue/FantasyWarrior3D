
--------------------------------
-- @module ProtocolIAP
-- @extend PluginProtocol
-- @parent_module plugin

--------------------------------
-- brief pay result callback
-- @function [parent=#ProtocolIAP] onPayResult 
-- @param self
-- @param #int ret
-- @param #char msg
        
--------------------------------
-- brief config the developer info
-- param devInfo This parameter is the info of developer,
-- different plugin have different format
-- warning Must invoke this interface before other interfaces.
-- And invoked only once.
-- @function [parent=#ProtocolIAP] configDeveloperInfo 
-- @param self
-- @param #map_table devInfo
        
return nil