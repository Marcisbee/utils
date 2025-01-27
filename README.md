# Various utilities
This repo contains various tiny sh utilities.

# dotenv.sh
Loads env variables from `.env` file.

### Default:
```sh
# .env:
# PORT=4000

# test.js:
# console.log(process.env.PORT)

./dotenv.sh -- node ./test.js
```

### Custom env file:
```sh
./dotenv.sh .env.development -- node ./test.js
```

## lslint.sh

This script helps you lint file paths in your project based on rules specified in a `.lslint` configuration file.

### Usage:
```sh
./lslint.sh
```

Before running this script, please create a `.lslint` configuration file in your project root directory. This file should contain valid file patterns you want to lint. For example:

```plaintext
/package.json
/node_modules/**/*
/src/<kebabcase>**/<kebabcase>.<:tsx|ts>
/src/<kebabcase>**/<kebabcase>.module.css
/test/**/<kebabcase>.test.ts
```

### Example Syntax Matches:

| Pattern                     | Matched File Paths                                        |
|-----------------------------|---------------------------------------------------------|
| `/file.ts`                  | `/file.ts`                                              |
| `/test/*`                   | `/test/file.ts` |
|                             | `/test/any.css` |
| `/test/**/*`                | `/test/file.ts` |
|                             | `/test/a/b/c/any.css`                    |
| `/test/**/file.ts`          | `/test/file.ts` |
|                             | `/test/a/file.ts` |
|                             | `/test/a/b/c/file.ts`   |
| `/test/**/*.ts`             | `/test/file.ts` |
|                             | `/test/a/any.ts` |
|                             | `/test/a/b/c/any.ts`    |
| `/test/start/**/end/*.ts`   | `/test/start/end/file.ts` |
|                             | `/test/start/a/end/any.ts` |
|                             | `/test/start/a/b/c/end/any.ts` |
| `/test/**/<kebabcase>.ts`   | `/test/paper-bag.ts` |
|                             | `/test/a/paper-bag.ts` |
|                             | `/test/a/b/c/paper-bag.ts` |
| `/test/<kebabcase>**/<kebabcase>.ts` | `/test/paper-bag.ts` |
|                             | `/test/component-setup/paper-bag.ts` |
|                             | `/test/component-setup/b/component-files/paper-bag.ts` |
| `/test/<:[A-Z]+>**/mod.<:ts\|tsx\|css>` | `/test/any.ts` |
|                             | `/test/component-setup/file.tsx` |
|                             | `/test/component-setup/b/component-files/paper-bag.css` |

---

# License
[MIT](LICENCE) &copy; [Marcis Bergmanis](https://twitter.com/marcisbee)
