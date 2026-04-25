package io.github.brainage04;

import net.fabricmc.api.ClientModInitializer;

public class FabricModdingTemplateClient implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        FabricModdingTemplate.LOGGER.info("{} client initialised.", FabricModdingTemplate.MOD_NAME);
    }
}
