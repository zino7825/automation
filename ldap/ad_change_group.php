<?php
###########################
#
#
# Change B group => A group 
#

set_time_limit ( 30 );
error_reporting ( E_ALL );
ini_set ( 'error_reporting', E_ALL );
ini_set ( 'display_errors', 1 );
$empno = '';
$empno = strtoupper($empno);
$ldapserver = 'ldap://{ip}';
$ldapuser      = '{id}';
$ldappass     = '{password}';
$ldapbase    = "OU=Admin,DC=example,DC=com";

$ldapconn = ldap_connect ( $ldapserver ) or die ( "Could not connect to LDAP server." );
if ($ldapconn) {
   $ldapbind = ldap_bind ( $ldapconn, $ldapuser,$ldappass) or die ( "Error trying to bind: " . ldap_error ( $ldapconn ) );
   if ($ldapbind) {
       $filter = "(&(objectclass=group)(cn=A))";
       $justthese = array('dn','member');
       $result1 = ldap_search ( $ldapconn,$ldapbase,$filter,$justthese);
       $data1 = ldap_get_entries ( $ldapconn, $result1 );

       $filter2 = "(&(objectclass=group)(cn=B))";
       $result2 = ldap_search ( $ldapconn,$ldapbase,$filter2);
       $result2 = ldap_search ( $ldapconn,$ldapbase,$filter2,$justthese);
       $data2 = ldap_get_entries ( $ldapconn, $result2 );

       if ( $data2[0]['member']['count'] > 0 ) {
           for ( $i=0 ; $i< $data2[0]['member']['count'] ; $i++) {

                       $entry["member"][] = $data2[0]["member"][$i];
           }
       }
       if ( count($entry['member']) > 0 )  {
         print_r($entry);
       }

   }
}
ldap_close ( $ldapconn );
?>
