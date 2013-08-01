// Stepper rotation
// args = serial # for stepper, new position (angle in degrees)

import com.phidgets.PhidgetException;
import com.phidgets.StepperPhidget;

public class Rotate {
    
     
    public static void main(String[] args) throws PhidgetException {
	if(args.length == 0){
	  System.out.println("Usage: java Rotate stepperserial degree");
	  System.exit(0);
	}
        int stepper_serial = Integer.parseInt(args[0]);
        int d = Integer.parseInt(args[1]);
       	System.out.println("*********** JAVA Rotate Program **************"); 
        // connect stepper
        System.out.println("Connecting stepper phidget " + stepper_serial + "...");
        StepperPhidget stepper = new StepperPhidget();
//       System.out.println("Object created");
	 stepper.open(stepper_serial);
	System.out.println("Opened ");
        stepper.waitForAttachment();
	System.out.println("Attached");
        stepper.setVelocityLimit(0, 899.0); // TODO: calibrate for lab setting
        stepper.setAcceleration(0, 64808.0);
        stepper.setCurrentLimit(0, 0.51);
//	System.out.println("Limits set");
        stepper.setEngaged(0, true);
        System.out.println("Connected: " + stepper.getSerialNumber());
//        System.out.println("Current limit: " + stepper.getCurrentLimit(0) + ". Velocity limit: " + stepper.getVelocityLimit(0));
        
        // rotate (translate d to steps)
	// phidget API: a change of 16 in position = 1 full step
	// phidget API: 1 full step = 0.9 degrees
	// so: (d / 0.9) * 16 = new physical stepper position
	long targetPos = (long) ((d / 0.9) * 16);
        stepper.setTargetPosition(0, targetPos);
	stepper.close();
//	stepper = null;
//	return 23;
    }
}
