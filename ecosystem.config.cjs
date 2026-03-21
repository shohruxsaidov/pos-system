module.exports = {
  apps: [
    {
      name: "pos-backend",
      cwd: "./backend",
      script: "src/server.js",
      interpreter: "node",
      interpreter_args: "--experimental-vm-modules",
      instances: 1,
      autorestart: true,
      watch: false,
      max_memory_restart: "512M",
      restart_delay: 3000,
      env: {
        NODE_ENV: "production",
        PORT: 3000,
      },
      env_development: {
        NODE_ENV: "development",
        PORT: 3000,
      },
      error_file: "./logs/backend-error.log",
      out_file: "./logs/backend-out.log",
      log_date_format: "YYYY-MM-DD HH:mm:ss",
      merge_logs: true,
    },
    {
      name: "pos-desktop",
      cwd: "./pos-desktop",
      script: "node_modules/.bin/vite",
      args: "preview --port 5173 --host",
      instances: 1,
      autorestart: true,
      watch: false,
      restart_delay: 3000,
      env: {
        NODE_ENV: "production",
      },
      env_development: {
        NODE_ENV: "development",
      },
      error_file: "./logs/desktop-error.log",
      out_file: "./logs/desktop-out.log",
      log_date_format: "YYYY-MM-DD HH:mm:ss",
      merge_logs: true,
    },
  ],
};
