package scorer;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;

/**
 * This class is used to score a list of products against a 
 * SAS rule table.
 * The scorer requires also a hierarchy table to assign the corresponding hierarchy nodes
 * to the list of products. The hierarchy table is assumed in a specific format.
 * (SAS Enterprise Miner format + a column indicating whether the row is a leaf or not)  
 * Both tables are expected to be accessible through the same JDBC connection passed to the scorer.
 * (see constructor below)
 * 
 * The hierarchy table is stored in memory for fast access. Further a file cache is created from the hierarchy
 * to accelerate test and debug efforts (loading the hierarchy takes about 1 - 2 minutes).
 */
public class RuleScorer {

	Connection m_con;
	Hierarchy m_hierarchy;
	String m_hierarchyCacheFile ;
	String m_driveHierarchyTable;
	String m_childColumn;
	String m_parentColumn;
	String m_ruleTable;

	/**
	 * This main method represents a sample usage of the scorer.
	 */
	public static void main(String[] args) {
		// define the JDBC driver
		try {
			System.out.println("Load JDBC driver");
			Class.forName("com.mysql.jdbc.Driver");
		} catch (Exception ex) {
			ex.printStackTrace();
		}
		

		// create the database connection
		// note: both tables need to be accessible through this single connection
		Connection con = null;
		try {
			System.out.println("get connection");
			con = DriverManager.getConnection("jdbc:mysql://localhost/test");

		} catch (SQLException ex) {
			System.out.println("SQLException: " + ex.getMessage());
			System.out.println("SQLState: " + ex.getSQLState());
			System.out.println("VendorError: " + ex.getErrorCode());
		} catch (Exception e) {
			e.printStackTrace();
		}

		try {
			System.out.println("Init Scorer:");
			// the absolut path for the hierarchy cache file to cache the hierarchy.
			// to reload the hierarchy from the database, the cache file must be deleted
			String hierarchyCacheFile = "C:\\eclipse\\workspace\\RuleScorer\\HierarchyCache\\HierarchyCachFile.obj";
			// name of the table where the drive hierarchy is stored
			String driveHierarchyTable = "drive_hierarchy";
			// name of the child column of the hierarchy table
			String childColumn = "Kind_ID_Bez"; 
			// name of the parent column of the hierarhy table
			String parentColumn =  "Eltern_ID_Bez";
			// name of the rule table (enterprise miner format)
			String ruleTable = "rules";
			
			RuleScorer scorer = new RuleScorer(con, hierarchyCacheFile, driveHierarchyTable, childColumn, parentColumn, ruleTable);
			scorer.init();

			// define a test market basket
			ArrayList<String> products = new ArrayList<String>();
			products.add("2441450000_EMMENTALER SCHEIBEN 250 G, ORIGINAL");
			products.add("130789004_YELLA BROTAUFSTRICH 200G");
			products.add("2666926007_GLOBUS GRANA PADANO 32% 20 MON.GEREIFT");
			products.add("2414833007_GLOBUS EIS 900ML, PFLAUME/ZIMT");
			products.add("1362937003_MÜLLERMILCH 400ML, SCHOKO");
			
			// score the test market basket against the rules
			System.out.println("Score basket:");
			long time = System.currentTimeMillis();
			ArrayList<Rule> rules = scorer.score(products);
			time = System.currentTimeMillis() - time;
			System.out.println("Scoring-Time: " + (time / 1000.0) + " sec.");

			// output the recommendations retrieved from the scorer
			System.out.println("Print rules:");
			if (rules != null) {
				int count = 0;
				for (Rule rule : rules) {
					count++;
					System.out.println(count + ": " + rule);
				}
			}
			System.out.println("finish:");

		} catch (Exception e) {
			e.printStackTrace();
		}
	}
	
	/**
	 * This mehtod scores a given list of products and returns the rules / recommendations.
	 * Scored are those rules whose consequence (recommendation) is not in the product list (and its hierarchy nodes)
	 * 
	 * @param products the list of products representing the market basket
	 * @return the fitting rules / recommendations
	 * @throws Exception
	 */
	public ArrayList<Rule> score(ArrayList<String> products) throws Exception {
		// first get all the hierarchy nodes for the products and add them to a hash set (avoids duplicates)
		HashSet<String> marketBasket = new HashSet<String>();
		for(String product : products) {
			// add the product itself
			marketBasket.add(product);
			
			// then get all the hierarchy nodes
			ArrayList<String> hierarchyNodes = m_hierarchy.getHierarchyNodesForLeaf(product);
			for(String node : hierarchyNodes) {
				marketBasket.add(node);
			}
		}
		
		// in a second step retrieve all rules, that match the basket
		// i.e. all rules whose left hand side matches the basket but not the right hand side
		Statement stmt = m_con.createStatement();
		
		// create the where-in part
		StringBuffer buf = new StringBuffer();
		for(String item : marketBasket) {
			buf.append("'").append(escapeQuotes(item)).append("'").append(",");
		}
		// remove the last comma which is not required
		String inPart = buf.toString().substring(0, buf.length()-1);
		System.out.println("InPart: " + inPart);
		
		// create the scoring query
		// this query must be adapted if more items are allowed within a rule
		String query =
			"select support, conf, lift, lhs, rule, item2, item3 " +
			" from " + m_ruleTable + " where " +
			"item1 in (" + inPart + ") and " +
			"item2 in (" + inPart + ") and " +
			"item3 not in (" + inPart + ") and " + 
			"lhs = 2 or " +
			"item1 in (" + inPart + ") and " +
			"item2 not in (" + inPart + ") and " +
			"lhs = 1";
		//	"select * from rules where item1 in (" + inPart + ") and item2 in (" + inPart + ")";
		System.out.println("Query: " + query);
		
		// execute the query against the database
		ResultSet result = stmt.executeQuery(query);
		
		// create the result with the rules / recommendations
		ArrayList<Rule> ruleList = new ArrayList<Rule>();
		while (result.next()) {
			float support = result.getFloat("support");
			float conf = result.getFloat("conf");
			float lift = result.getFloat("lift");
			int lhs = result.getInt("lhs");
			String rule = result.getString("rule");
			
			// dependant on the lhs value we can determine which item is the rule rhs (consequece)
			// an thus represents the recommendation
			String recommendation = null;
			if(lhs == 1) {
				recommendation = result.getString("item2");
			} else if(lhs == 2) {
				recommendation = result.getString("item3");
			} else {
				throw new RuntimeException("Not expected rule due to wrong lhs value: " + lhs);
			}
			
			Rule ruleObj = new Rule(rule, recommendation, support, conf, lift);
			ruleList.add(ruleObj);
			
		}
		return ruleList;
	}
	
	private String escapeQuotes(String string) {
		return string.replaceAll("'", "''");
	}

	/**
	 * @param args
	 */
	public void init() {

		try {
			m_hierarchy = new Hierarchy(m_con, m_hierarchyCacheFile, m_driveHierarchyTable,
					m_childColumn, m_parentColumn);
			m_hierarchy.buildHierarchy();
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	public RuleScorer(Connection con, String hierarchyCacheFile,
			String driveHierarchyTable,	String childColumn, String parentColumn,	String ruleTable) {
		m_con = con;
		m_hierarchyCacheFile = hierarchyCacheFile;
		m_driveHierarchyTable = driveHierarchyTable;
		m_childColumn = childColumn; 
		m_parentColumn =  parentColumn;
		m_ruleTable = ruleTable;
	}
}
