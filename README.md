# orchardDB
:apple: :deciduous_tree: A set of publicly available amino acid sequences from various genome portals and projects for use with the Orchard pipeline.


## Dependencies
### Perl
 * Bioperl
 * DateTime
 
```
  sudo cpanm Bio::Perl DateTime
```
### MySQL
#### Username & Password Access
You will need to set up a username and password for the database access.
```
  mysql -u root -p
  
  mysql> CREATE USER 'orcharddb'@'localhost' IDENTIFIED BY 'password';
  mysql> GRANT ALL PRIVILEGES ON *.* TO 'orcharddb'@'localhost';
  mysql> FLUSH PRIVILEGES;
```
