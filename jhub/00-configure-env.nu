# Ensure your environment is configured appropriately

print "[ INFO ] Configuring environment"
vim ./env.nu
print "[ INFO ] Environment configured:"
print (open ./env.nu)
input -n 1 "[ PROMPT ] Does this look correct? [Y/n] "
| if $in != "n" { ignore } else { print "[ INFO ] Exiting. Please rerun to reconfigure env."; exit 1 }
