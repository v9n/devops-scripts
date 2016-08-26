clean:
	rm s3.zip

s3.zip:
	zip -r s3.zip index.js node_modules

build: clean s3.zip

test:
	mocha

deploy: build
	aws lambda update-function-code \
		--function-name ProcessS3Upload \
		--zip-file fileb://./s3.zip \
		--profile your-profile
