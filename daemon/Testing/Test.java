import java.lang.Class;

public class Test
{
	public static void main(String [] args)
	{
		DhvTestMsg msg = new DhvTestMsg();
		System.out.println("hello \n");

		try{		
		System.out.println(args[0]);
		Class c = Class.forName(args[0]);
		System.out.println("\n bye \n");
		}catch(Exception e)
		{
			System.out.println(" Error : ");
			System.out.println(e.getMessage());
		}
		
	}

}
