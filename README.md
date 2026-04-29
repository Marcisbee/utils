# Various utilities

This repository contains several shell utility scripts designed to facilitate various tasks in your development workflow.

## dotenv.sh

The `dotenv.sh` script loads environment variables from a `.env` file. This can be particularly useful for setting up your application's configuration in different environments without hardcoding sensitive information into your source code.

### Default Usage:

```sh
# .env:
# PORT=4000

# test.js:
# console.log(process.env.PORT);

./dotenv.sh -- node ./test.js
```

or

```sh
curl -SsfL https://marcisbee.github.io/utils/dotenv.sh | bash -s -- -- node ./test.js
```

The script loads the environment variables from `.env` by default and runs the specified command, in this case, `node ./test.js`.

### Using a Custom Environment File:

If you need to load environment variables from a different file (e.g., for development or testing environments), specify it as follows:

```sh
./dotenv.sh .env.development -- node ./test.js
```

or

```sh
curl -SsfL https://marcisbee.github.io/utils/dotenv.sh | bash -s -- .env.development -- node ./test.js
```

## serve.sh

The `serve.sh` script serves static files from a local directory using Bash and `nc`. It is useful when you need a tiny local web server for HTML, CSS, JavaScript, images, or JSON without requiring Node, PHP, or Python.

### Usage:

```sh
./serve.sh 8000 ./public
```

or

```sh
curl -SsfL https://marcisbee.github.io/utils/serve.sh | bash -s -- 8000 ./public
```

Then open:

```sh
http://localhost:8000/
```

Requests to `/` are mapped to `index.html`. This is intended for local development and simple static files, not production serving.

The script requires `nc` with support for the `-k` option. If `nc` is missing or incompatible, it exits with a clear error.

For single-page applications, use `--spa` to serve `index.html` for route-like paths that do not map to a real file:

```sh
./serve.sh 8000 ./dist --spa
```

Responses include `Cache-Control: no-store` so browser refreshes pick up changed CSS and JavaScript. The script serves common static file types including HTML, CSS, JavaScript, source maps, JSON, images, fonts, WASM, PDF, audio, and video.

## lslint.sh

The `lslint.sh` script assists in linting the file paths within your project according to rules specified in a `.lslint` configuration file. This is helpful for maintaining consistency and ensuring that all necessary files adhere to the specified patterns.

### Usage:

Create a `.lslint` configuration file in your project's root directory with the desired file patterns. Here’s an example of how to set it up:

```sh
# .lslint
# /package.json
# /node_modules/**/*
# /src/<kebabcase>**/<kebabcase>.<:tsx|ts>
# /src/<kebabcase>**/<kebabcase>.module.css
# /test/**/<kebabcase>.test.ts

./lslint.sh
```

Before running the script, ensure that the `.lslint` configuration file exists in your project root directory. Here are some example syntax matches for typical linting patterns:

| Pattern                         | Matched File Paths                                            |
|---------------------------------|---------------------------------------------------------------|
| `/file.ts`                      | `/file.ts`                                                    |
| `/test/*`                       | `/test/file.ts`, `/test/any.css`                              |
| `/test/**/*`                    | `/test/file.ts`, `/test/a/b/c/any.css`                        |
| `/test/**/file.ts`              | `/test/file.ts`, `/test/a/file.ts`, `/test/a/b/c/file.ts`     |
| `/test/**/*.ts`                 | `/test/file.ts`, `/test/a/any.ts`, `/test/a/b/c/any.ts`       |
| `/test/start/**/end/*.ts`       | `/test/start/end/file.ts`, `/test/start/a/end/any.ts`, ...    |
| `/test/**/<kebabcase>.ts`       | `/test/paper-bag.ts`, `/test/a/paper-bag.ts`, ...             |
| `/test/<kebabcase>**/<kebabcase>.ts` | `/test/paper-bag.ts`, ...                                |
| `/test/<:[A-Z]+>**/mod.<:ts\|tsx\|css>` | `/test/any.ts`, ...                                    |

## tasks.sh

The `tasks.sh` script allows you to define and execute shell functions as tasks. These tasks are defined in a separate `task.sh` file within your project's root directory.

### Usage:

```sh
./tasks.sh <task_name|task_group>
```

or

```sh
curl -SsfL https://marcisbee.github.io/utils/tasks.sh | bash -s -- <task_name|task_group>
```

- **Single Task**: Execute the function by specifying its name, e.g., `./tasks.sh build`.

- **Task Group**: Run multiple tasks concurrently by combining their names with a `+`, e.g., `./tasks.sh build+lint`.

### Instructions:

1. Ensure a `task.sh` file exists in your project's root directory.

2. Define bash functions prefixed with `task_`. For example:

   ```sh
   #!/usr/bin/env bash

   task_dev() {
     start_task build
     start_task db+server
   }

   task_server() {
     echo "Start server process"
   }

   task_db() {
     echo "Start db process"
   }

   task_build() {
     echo "This is build"
   }
   ```

3. Run the `tasks.sh` script with the desired task name or group of tasks.

The script includes error handling and cleanup procedures to manage running processes effectively. When combined task names (e.g., `build+lint`) are provided, each specified task runs concurrently; otherwise, they run sequentially.

## Development

For linting shell scripts, use the following command:

```sh
curl -SsfL https://marcisbee.github.io/gh/dl.sh | bash -s -- --repo koalaman/shellcheck
./shellcheck lslint.sh
```

## License

[MIT](LICENCE) &copy; [Marcis Bergmanis](https://twitter.com/marcisbee)
