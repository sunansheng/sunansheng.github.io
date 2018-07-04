cd _site
find . -name '*' -mmin -30 ! -name '.' |xargs -i cp {} --parents -prf ../_sitenew;
