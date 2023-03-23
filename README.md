# Programmentwurf TIT20 2022
This program takes a list of timestamps, calculates the differences in time between the given timestamps, and outputs the result.

### dependencies
 - nasm
 - gcc
 - make

## installation
Ubuntu:
```
sudo apt install make nasm
git clone https://github.com/baldur132/Sysprog-TIT20.git
cd Sysprog-TIT20/pe2022/
make
```

## usage
Normal Usage:
```
cd pe2022/
make
cat eingabe.txt | ./timediff
```

List Unit Test:
```
cd pe2022/
make
./list_test
```


