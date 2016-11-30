clean:
	rm fastly.zip

fastly.zip:
	zip -r fastly.zip index.js node_modules

build: clean fastly.zip

test:
	mocha

deploy: build
	aws lambda update-function-code \
		--function-name ProcessAutoScaleEvent \
		--zip-file fileb://./fastly.zip \
		--profile your-profile
