cd _site
find . -name '*.*' -mmin -1000 ! -name '.' |xargs -i cp {} --parents -prf ../_sitenew;
