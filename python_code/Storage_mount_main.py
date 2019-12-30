#!/usr/bin/python3.6
#
#  history:
#  Mark Lu initialized 10-June-2019 for snapcreator mount operation 
#
#
#
###################################################################

import sys,getopt
import os,subprocess,smtplib
from subprocess import Popen, PIPE, STDOUT
import os.path as op
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email.mime.text import MIMEText
from email.utils import COMMASPACE, formatdate
from email import encoders

def get_env():
  global SNAPSERVERNAME 
  global PROFILENAME 
  global SOURCECONFIGNAME 
  global TARGETCONFIGNAME 
  global POLICYNAME 
  global SNAPSHOTLABELNAME 
  global SNAPCREATORNAME 
  global EMAILLIST 
  global LOGFILE 
  global PW 
  global TARGETHOST
  print("getting enviroment")
  ar = sys.argv
  c=len(ar)
  if  c != (2): 
    print("wrong arugment") 
    sys.exit(1)
  ar1 = sys.argv[1]
  TARGETHOST = ar1
  command = " ls  /opt/snap_creator/scripts/config/"  + ar1 +".conf" 
  return_cd=os.system(command)
  print(return_cd)
  if return_cd != 0:
    print("no configuration file exist..")
    sys.exit(1)
  else:
    p = subprocess.Popen(command, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
    p_out = p.stdout.read().decode()
    p_out = p_out.rstrip(os.linesep)
    print('file is ',p_out)
    com = "grep SNAPSERVERNAME " + p_out + " |cut -d: -f2"
    SNAPSERVERNAME = subprocess.Popen(com, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
    SNAPSERVERNAME = SNAPSERVERNAME.stdout.read().decode()
    SNAPSERVERNAME = SNAPSERVERNAME.rstrip(os.linesep)
    print("SNAPSERVERNAME is ", SNAPSERVERNAME)
    com = "grep PROFILENAME " + p_out + " |cut -d: -f2"
    PROFILENAME = subprocess.Popen(com, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
    PROFILENAME = PROFILENAME.stdout.read().decode()
    PROFILENAME = PROFILENAME.rstrip(os.linesep)
    print("PROFILENAME is ", PROFILENAME)
    com = "grep SOURCECONFIGNAME " + p_out + " |cut -d: -f2"
    SOURCECONFIGNAME = subprocess.Popen(com, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
    SOURCECONFIGNAME = SOURCECONFIGNAME.stdout.read().decode()
    SOURCECONFIGNAME = SOURCECONFIGNAME.rstrip(os.linesep)
    print("SOURCECONFIGNAME is ", SOURCECONFIGNAME)
    com = "grep TARGETCONFIGNAME " + p_out + " |cut -d: -f2"
    TARGETCONFIGNAME = subprocess.Popen(com, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
    TARGETCONFIGNAME = TARGETCONFIGNAME.stdout.read().decode()
    TARGETCONFIGNAME = TARGETCONFIGNAME.rstrip(os.linesep)
    print("TARGETCONFIGNAME is ", TARGETCONFIGNAME)
    com = "grep POLICYNAME " + p_out + " |cut -d: -f2"
    POLICYNAME = subprocess.Popen(com, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
    POLICYNAME = POLICYNAME.stdout.read().decode()
    POLICYNAME = POLICYNAME.rstrip(os.linesep)
    print("POLICYNAME is ", POLICYNAME)
    com = "grep SNAPSHOTLABELNAME " + p_out + " |cut -d: -f2"
    SNAPSHOTLABELNAME = subprocess.Popen(com, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
    SNAPSHOTLABELNAME = SNAPSHOTLABELNAME.stdout.read().decode()
    SNAPSHOTLABELNAME = SNAPSHOTLABELNAME.rstrip(os.linesep)
    print("SNAPSHOTLABELNAME is ", SNAPSHOTLABELNAME)
    com = "grep SNAPCREATORNAME " + p_out + " |cut -d: -f2"
    SNAPCREATORNAME = subprocess.Popen(com, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
    SNAPCREATORNAME = SNAPCREATORNAME.stdout.read().decode()
    SNAPCREATORNAME = SNAPCREATORNAME.rstrip(os.linesep)
    print("SNAPCREATORNAME is ", SNAPCREATORNAME)
    com = "grep EMAILLIST " + p_out + " |cut -d: -f2"
    EMAILLIST = subprocess.Popen(com, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
    EMAILLIST = EMAILLIST.stdout.read().decode()
    EMAILLIST = EMAILLIST.rstrip(os.linesep)
    print("EMAILLIST is ", EMAILLIST)
    com = "grep LOGFILE " + p_out + " |cut -d: -f2"
    LOGFILE = subprocess.Popen(com, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
    LOGFILE = LOGFILE.stdout.read().decode()
    LOGFILE = LOGFILE.rstrip(os.linesep)
    print("LOGFILE is ", LOGFILE)
    com = "mv "  + LOGFILE  + " " + LOGFILE +"_1"
    MVLOGFILE = subprocess.Popen(com, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
    MVLOGFILE = MVLOGFILE.stdout.read().decode()
    MVLOGFILE = MVLOGFILE.rstrip(os.linesep)
    print(MVLOGFILE)
    com = "grep snapcreate  /opt/snap_creator/scripts/.pw |cut -f 2 -d ':'"
    PW = subprocess.Popen(com, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
    PW = PW.stdout.read().decode()
    PW = PW.rstrip(os.linesep)
    

def getbackupname():
  global backupname
  com = SNAPCREATORNAME +" --server " +  SNAPSERVERNAME + " --port 8443 --user snapcreate --passwd " + PW + " --profile "+ PROFILENAME + " --config " + SOURCECONFIGNAME  + " --action backupList | awk '{print $1} ' | sort -u   | tail -1   " 
  backupname = subprocess.Popen(com, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
  backupname = backupname.stdout.read().decode()
  
  print(backupname)
             
def fun_umount():
  print(LOGFILE)
  com = SNAPCREATORNAME + " --server " +  SNAPSERVERNAME + " --port 8443 --user snapcreate --verbose --passwd " + PW + " --profile "+ PROFILENAME + " --config " + TARGETCONFIGNAME  + " --action umount --policy " + POLICYNAME + " --backupName " + backupname 
  #print(com)
  with subprocess.Popen(com, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, bufsize=1) as com_umount, \
    open(LOGFILE,'ab') as file:
    for line in com_umount.stdout:
      sys.stdout.buffer.write(line)
      file.write(line)
    com_umount.wait()
  #print(com_umount.communicate()[0])
  if com_umount.returncode == 0:
    print("umount ran good")
  else:
    print("umount not good, may already umounted")
    send_mail("root",[EMAILLIST], "umount command is having issues", "umount command is having issues", [LOGFILE])
  
def fun_cloneDel():
  com = SNAPCREATORNAME + " --server " +  SNAPSERVERNAME + " --port 8443 --user snapcreate --verbose --passwd " + PW + " --profile "+ PROFILENAME + " --config " + TARGETCONFIGNAME  + " --action cloneDel --policy " + POLICYNAME 
  #print(com)
  with subprocess.Popen(com, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, bufsize=1) as com_cloneDel, \
    open(LOGFILE,'ab') as file:
    for line in com_cloneDel.stdout:
      sys.stdout.buffer.write(line)
      file.write(line)
    com_cloneDel.wait()
  if com_cloneDel.returncode == 0:
    print("cloneDel ran good")
  else:
    print("cloneDel not good")
    send_mail("root",[EMAILLIST], "cloneDel command is having issues", "cloneDel command is having issues", [LOGFILE])


def fun_mount():
  print("here is mount")
  processes = []
  com = SNAPCREATORNAME + " --server " +  SNAPSERVERNAME + " --port 8443 --user snapcreate --verbose --passwd " + PW + " --profile "+ PROFILENAME + " --config " + TARGETCONFIGNAME  + " --action mount --policy " + POLICYNAME + " --backupName " + backupname  
  #print(com)
  #com_mount = subprocess.Popen(com, shell=True, stdin=PIPE, stdout=log, stderr=log, close_fds=True)  
  with subprocess.Popen(com, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, bufsize=1) as com_mount, \
    open(LOGFILE,'ab') as file:
    for line in com_mount.stdout:
      sys.stdout.buffer.write(line)
      file.write(line)
    com_mount.wait()
  #print(com_mount.communicate())
  if com_mount.returncode == 0:
    print("mount ran good")
  else:
    print("mount not good")

def fun_remount():
  fun_checkstatus()
  i = 0
  while  MOUNTSTATUS != 'successful':
    fun_mount()
    fun_checkstatus()
    i += 1
    if i > 2:
      print("already tried ",i," times, gave up.., email admin")
      send_mail("root",[EMAILLIST], "mount is having issues", "mount is having issues", [LOGFILE])
      sys.exit(1)

def test():
  com = "pwd;ls" 
  print(com)
  #com_mount = subprocess.Popen(com, shell=True, stdin=PIPE, stdout=log, stderr=log, close_fds=True)  
  with subprocess.Popen(com, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, bufsize=1) as p, \
    open("/tmp/mytest.log",'wb+') as file:
    for line in p.stdout:
      sys.stdout.buffer.write(line)
      file.write(line)
    p.wait()
  #print(com)
  print(EMAILLIST)
  print(LOGFILE)
  send_mail("root",[EMAILLIST], "test", "body text", [LOGFILE])

def fun_checkstatus():
  global MOUNTSTATUS
  com = SNAPCREATORNAME + "  --server "  + SNAPSERVERNAME  + " --port 8443 --user snapcreate --passwd  " + PW  + "  --action jobStatus |grep " + PROFILENAME + " |grep " + TARGETCONFIGNAME + " |grep mount |grep -v umount |sort -n | tail -1 |awk '{print $2}'"
  com_MOUNTSTATUS = subprocess.Popen(com, shell=True, stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)  
  MOUNTSTATUS = com_MOUNTSTATUS.communicate()[0].decode()
  MOUNTSTATUS = MOUNTSTATUS.rstrip('\n') 
  print("MOUNTSTATUS is ",MOUNTSTATUS)



def final_check():
  if MOUNTSTATUS != "successful":
    send_mail("root",[EMAILLIST], "test", "body text", [LOGFILE])
    print("final check mount failed") 
    sys.exit(1)
  else:
    print("final check mount good")  

def email_admin():
  s = smtplib.SMTP('localhost')
  msg = TARGETHOST + " mount is having issues"
  s.sendmail("root",EMAILLIST, msg)
  s.quit


def send_mail(send_from, send_to, subject, message, files=[],
              server="localhost", port=587, username='', password='',
              use_tls=True):

    msg = MIMEMultipart()
    msg['From'] = send_from
    msg['To'] = COMMASPACE.join(send_to)
    msg['Date'] = formatdate(localtime=True)
    msg['Subject'] = subject

    msg.attach(MIMEText(message))

    for path in files:
        part = MIMEBase('application', "octet-stream")
        with open(path, 'rb') as file:
            part.set_payload(file.read())
        encoders.encode_base64(part)
        part.add_header('Content-Disposition',
                        'attachment; filename="{}"'.format(op.basename(path)))
        msg.attach(part)

    #smtp = smtplib.SMTP(server, port)
    smtp = smtplib.SMTP(server)
    smtp.sendmail(send_from, send_to, msg.as_string())
    smtp.quit()

def main():
  get_env()
  getbackupname()
  #test()
  fun_umount()
  fun_cloneDel()
  fun_mount()
  fun_remount()
  final_check()
  


if __name__=="__main__":
  main()
