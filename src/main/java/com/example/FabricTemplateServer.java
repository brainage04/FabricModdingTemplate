package com.example;

import com.example.command.core.ModCommands;
import com.example.config.ExampleConfig;
import net.fabricmc.api.ModInitializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class FabricTemplateServer implements ModInitializer {
    public static final String MOD_ID = "fabrictemplateserver";
    public static final String MOD_NAME = "FabricTemplateServer";
	public static final Logger LOGGER = LoggerFactory.getLogger(MOD_NAME);

	@Override
	public void onInitialize() {
        LOGGER.info("{} initialising...", MOD_NAME);

        ExampleConfig.init();
        ModCommands.initialize();

        if (ExampleConfig.CONFIG.logConfigOnStartup.get()) {
            LOGGER.info(
                    "Loaded config: message='{}', mode={}, featuredItem={}, retries={}",
                    ExampleConfig.CONFIG.welcomeMessage.get(),
                    ExampleConfig.CONFIG.syncMode.get(),
                    ExampleConfig.CONFIG.featuredItem.get(),
                    ExampleConfig.CONFIG.startupRetries.get()
            );
        }

        LOGGER.info("{} initialised.", MOD_NAME);
	}
}
