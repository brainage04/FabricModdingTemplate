package com.example;

import net.fabricmc.api.ClientModInitializer;

public class FabricTemplateServerClient implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        FabricTemplateServer.LOGGER.info("{} client initialised.", FabricTemplateServer.MOD_NAME);
    }
}
