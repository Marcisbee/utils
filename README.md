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

---

# License
[MIT](LICENCE) &copy; [Marcis Bergmanis](https://twitter.com/marcisbee)
