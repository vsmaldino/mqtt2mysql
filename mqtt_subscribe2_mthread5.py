import signal
import logging
import threading
import time
from datetime import datetime
from queue import Queue, Empty
import paho.mqtt.client as mqttClient
import mysql.connector as mysql
from mysql.connector import errorcode

# Global variables
class tElement:
  def __init__(self, timestamp, userdata, message):
    self.timestamp = timestamp
    self.userdata = userdata
    self.message = message
  # __init__
# tElement
Exiting = False # to force exit from the dequeue Thread
mqConnected = False # global variable for the state of the broker connection
dbConnected = False # global variable for the state of the database connection
broker_address= "mqtt.myhost.it" # Broker address
user = "user" # Connection username
password = "pass" # Connection password
clientid = "pyth2" # identificator for the MQTT client
mpipeline = Queue(maxsize=100) # max queue elements
connectparams = {
    'user': 'dbuser', 
    'password': 'dbpass',
    'host': 'mysql.myhost.it',
    'database': 'sensors',
    'port': 3306
}
# End of Global Variables


def main():
  global mqConnected
  global Exiting
  global dbconn
  
  formatstr = "%(asctime)s: %(message)s"
  # signal.signal(signal.SIGINT, receiveSignal)
  signal.signal(signal.SIGTERM, receiveSignal)
  logging.basicConfig(format=formatstr, level=logging.INFO,
                      datefmt="%H:%M:%S")
  client = mqttClient.Client(clientid) #create new instance
  client.username_pw_set(user, password) #set username and password
  client.on_connect= on_connect #attach function to callback
  client.on_message= on_message #attach function to callback
  client.connect(broker_address) #connect to broker
  client.loop_start()        #start the loop
  
  logging.debug("Connecting")
  while mqConnected != True:    #Wait for connection
    logging.debug("Still connecting")
    time.sleep(0.1)
  ## DBconnect()
  dQt = threading.Thread(target=dequeueMessage)
  dQt.start()
  
  try:
    while True:
      time.sleep(0.2)
  except KeyboardInterrupt:
  #Exit point
    logging.info ("exiting")
    Exiting = True
    client.disconnect()
    client.loop_stop()
    ## DBdisconnect()
# end of main()


def receiveSignal(signalNumber, frame):
  logging.info('Received:' + str(signalNumber))
  raise KeyboardInterrupt # to use the same handler
  return
# receiveSignal


def on_connect(client, userdata, flags, rc):
  global mqConnected #Use global variable
  global topics
  
  if rc == 0:
    logging.info("Connected to broker")
    topicstr="it/smaldino/home/terrace/wemosd1/out/sens/light"
    logging.info("Subscribing " + topicstr)
    client.subscribe(topicstr)
    topicstr="it/smaldino/home/terrace/wemosd1/out/sens/pressbme"
    logging.info("Subscribing " + topicstr)
    client.subscribe(topicstr)
    topicstr="it/smaldino/home/terrace/wemosd1/out/sens/tempdallas"
    logging.info("Subscribing " + topicstr)
    client.subscribe(topicstr)
    topicstr="it/smaldino/home/terrace/wemosd1/out/sens/tempbme"
    logging.info("Subscribing " + topicstr)
    client.subscribe(topicstr)
    topicstr="it/smaldino/home/terrace/wemosd1/out/sens/humbme"
    logging.info("Subscribing " + topicstr)
    client.subscribe(topicstr)
    topicstr="it/smaldino/home/terrace/wemosd1/out/sens/bat"
    logging.info("Subscribing " + topicstr)
    client.subscribe(topicstr)
    topicstr="it/smaldino/home/terrace/wemosd1/out/reading"
    logging.info("Subscribing " + topicstr)
    client.subscribe(topicstr)
    topicstr="it/smaldino/home/boiler/wemosd1/out/reading"
    logging.info("Subscribing " + topicstr)
    client.subscribe(topicstr)
    topicstr="it/smaldino/home/boiler/wemosd1/out/tempdallas1"
    logging.info("Subscribing " + topicstr)
    client.subscribe(topicstr)
    topicstr="it/smaldino/home/boiler/wemosd1/out/tempdallas2"
    logging.info("Subscribing " + topicstr)
    client.subscribe(topicstr)
    mqConnected = True   #Signal connection         
  else:
    logging.error("Connection failed")
# end of on_connect()


def on_message(client, userdata, message):
  logging.debug("Received message")
  mMt = threading.Thread(target=enqueueMessage, args=(userdata, message,))
  mMt.start()
  # queueMessage(userdata, message)
# end of on_message()
 

def enqueueMessage(userdata, message):
  try:
    logging.debug("In enqueueMessage")
    te = tElement(datetime.now(), userdata, message)
    mpipeline.put(te)
    dateTimeObj = datetime.now()
    timestampStr = dateTimeObj.strftime("%Y-%m-%d %H:%M:%S")
    # logging.debug ("Timestamp : " + timestampStr)
    logging.debug ("**Topic     : " + message.topic)
    logging.debug ("**  Message : " + str(message.payload, "utf-8"))
    logging.debug ("**  QOS     : " + str(message.qos))
    logging.debug ("**  Retain  : " + str(message.retain))
    logging.debug ("**  Userdata: " + str(userdata))
  except Exception as e:
    logging.error(e)  
# end of enqueueMessage()


def dequeueMessage():
  global Exiting
  
  logging.debug("In dequeueMessage")
  while ((not Exiting) or (mpipeline.qsize()>0)):
    # Pausa per evitare il duplicated key
    # time.sleep(1)
    logging.debug("Waiting for message")
    # te dovrebbe essere di tipo tElement
    try:
      tte = mpipeline.get(timeout=1) # after 1 sec raises an Empty exception
      logging.debug("Got message")
      timestampStr = tte.timestamp.strftime("%Y-%m-%d %H:%M:%S")
      logging.debug ("*d*Topic     : " + str(tte.message.topic))
      logging.debug ("*d*  Message : " + str(tte.message.payload, "utf-8"))
      logging.debug ("*d*  QOS     : " + str(tte.message.qos))
      logging.debug ("*d*  Retain  : " + str(tte.message.retain))
      logging.debug ("*d*  Userdata: " + str(tte.userdata))
      
      topicstr = str(tte.message.topic)
      if ((topicstr == "it/smaldino/home/terrace/wemosd1/out/reading") or
          (topicstr == "it/smaldino/home/boiler/wemosd1/out/reading")):     # i comandi
        DBwriteEvent("SIG", tte.timestamp, topicstr, "TXT", 0, str(tte.message.payload, "utf-8"))
        # pass
      else: # gli altri casi cioè i valori
        DBwriteEvent("SEN", tte.timestamp, topicstr, "NUM", tte.message.payload, "")
      # end of if 
      
    except Empty:
      pass
    except Exception as e:
      logging.error(e)
# end of queueMessage()


def DBwriteEvent(eventType, timest, topic, dataType, num, text):
  # eventtype SIG / SEN signal/sensor
  global dbconn
  global dbConnected
  
  DBconnect()
  if dbConnected:
    try:
      if (eventType == "SIG"):
        strquery = 'INSERT INTO t_BoardSignal(ReadTime,SignalTopic,DataValType,NumVal,TextVal)'
      else:
        strquery = 'INSERT INTO t_SensorValue(ReadTime,SensorTopic,DataValType,NumVal,TextVal)'
      # end if
      strquery = strquery + 'VALUES'
      strquery = strquery + '(%s, %s, %s, %s, %s)'
      cursor = dbconn.cursor(prepared=True)
      insert_tuple = (timest, topic, dataType, num, text)
      cursor.execute(strquery, insert_tuple)
      dbconn.commit()
      logging.info("Inserted " + topic)
    except mysql.IntegrityError as err1:
      logging.warn(str(err1)) 
    except mysql.Error as err:
      logging.error(str(err))
  else:
    logging.warn("DB not connected")
  # end if
  DBdisconnect()
# end of DBwriteEvent


def DBconnect():
  global dbconn
  global dbConnected
  
  logging.debug("In DBconnect")
  try:
    dbconn = mysql.connect(**connectparams)
    if dbconn.is_connected():
      dbConnected = True
      db_Info = str(dbconn.get_server_info())
      start = db_Info.find("'") + 1
      end = db_Info.rfind("'")
      db_Info = db_Info[start:end]
      
      logging.info("Connected to MySQL Server version " + str(db_Info))
  except mysql.Error as err:
    if err.errno == errorcode.ER_ACCESS_DENIED_ERROR:
      logging.error("Something is wrong with your user name or password")
    elif err.errno == errorcode.ER_BAD_DB_ERROR:
      logging.error("Database does not exist")
    else:
      logging.error(str(err))
# end of DBconnect


def DBdisconnect():
  try:
    logging.info("Disconnecting from MySQL Server")
    dbconn.close()
  except:
    pass
# end of DBdisconnect

if __name__ == "__main__":
  main()
