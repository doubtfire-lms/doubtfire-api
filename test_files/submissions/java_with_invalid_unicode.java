
/**
 * Class to  show the remarks based on marks
 */
public class Exercise2 {

	/**
	 * This runs the tests on the exercise method
	 * @param args the command line arguments (non needed)
	 */
	public static void main(String[] args) {
		System.out.println("Mark Evaluator");

		int mark = 0;
		System.out.println("\n Mark = "+mark);
		System.out.println("Expected: Mark out of range");
		System.out.println("Output: "+markEvaluator(mark));


		mark = 6;
		System.out.println("\n Mark = "+mark);
		System.out.println("Expected: Mark out of range");
		System.out.println("Output: "+markEvaluator(mark));

		mark = 5;
		System.out.println("\n Mark = "+mark);
		System.out.println("Expected: Fail");
		System.out.println("Output: "+markEvaluator(mark));

		mark = 4;
		System.out.println("\n Mark = "+mark);
		System.out.println("Expected: Pass");
		System.out.println("Output: "+markEvaluator(mark));

		mark = 3;
		System.out.println("\n Mark = "+mark);
		System.out.println("Expected: Good");
		System.out.println("Output: "+markEvaluator(mark));

		mark = 2;
		System.out.println("\n Mark = "+mark);
		System.out.println("Expected: Very good");
		System.out.println("Output: "+markEvaluator(mark));

		mark = 1;
		System.out.println("\n Mark = "+mark);
		System.out.println("Expected: Excellent");
		System.out.println("Output: "+markEvaluator(mark));
	}

	/**
	 * This method receives a mark
	 * It return a string (�Excellent�, �Very good�, �Good�, �Pass�, �Fail� or �Mark out of range�).
	 * @param mark the marks received
	 * @return the String remarks
	 */
	private static String markEvaluator(int mark){
		switch (mark) {
		case 1: return "Excellent";
		case 2: return "Very Good";
		case 3: return "Good";
		case 4: return "Pass";
		case 5: return "Fail";
		default: return "Mark out of range";

		}
	}
}
