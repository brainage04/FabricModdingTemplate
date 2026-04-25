package io.github.brainage04.fabricmoddingtemplate;

import io.github.brainage04.fabricmoddingtemplate.command.core.ClientModCommands;
import net.fabricmc.api.ClientModInitializer;

public class FabricModdingTemplateClient implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        ClientModCommands.initialize();

        FabricModdingTemplate.LOGGER.info("{} client initialised.", FabricModdingTemplate.MOD_NAME);
    }
}
