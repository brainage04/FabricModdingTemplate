package com.example;

import com.example.command.core.ModCommands;
import com.example.config.ExampleConfig;
import net.fabricmc.api.ModInitializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ExampleMod implements ModInitializer {
    public static final String MOD_ID = "examplemod";
    public static final String MOD_NAME = "ExampleMod";
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
