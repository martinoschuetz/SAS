package scorer;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.HashMap;

/**
 * This class holds the product hierarchy in memory for fast access.
 * It is intended to pass a leaf product and retrieve the path upwards. 
 * This path are the hierchy nodes to add into the basket for later scoring
 */
public class Hierarchy {
	
	Connection m_con;
	String m_hierarchyCacheFile;
	String m_table;
	String m_kindSpalte;
	String m_elternSpalte;
	HashMap<String, Path> m_hierarchyMap;

	public Hierarchy(Connection con, String hierarchyCacheFile, String table, String kindSpalte,
			String elternSpalte) {
		m_con = con;
		m_hierarchyCacheFile = hierarchyCacheFile;
		
		m_table = table;
		m_kindSpalte = kindSpalte;
		m_elternSpalte = elternSpalte;

		m_hierarchyMap = new HashMap<String, Path>();
	}

	/**
	 * Build up the hierachy.
	 * Either from the database or from the cache file if available
	 * 
	 * @throws Exception
	 */
	public void buildHierarchy() throws Exception {
		// first ceck if the hierarchy is stored on disk in a file chach
		File hierarchyFile = new File(m_hierarchyCacheFile);
		if (hierarchyFile.exists()) {
			System.out.println("Create hierarchy from file cach:");
			// the file exists so load from the file cach
			ObjectInputStream input = new ObjectInputStream(new FileInputStream(hierarchyFile));
			
			m_hierarchyMap = (HashMap<String, Path>)input.readObject(); 
			m_hierarchyMap.toString();

		} else {
			System.out.println("Create hierarchy from database:");
			// first retrieve all leaf entries into an array list
			Statement stmt = m_con.createStatement();

			ResultSet set = stmt.executeQuery("select " + m_kindSpalte
					+ " from " + m_table + " where ist_blatt = 1");

			System.out.println("retrieve results");
			ArrayList<String> leafs = new ArrayList<String>();
			int count = 0;
			while (set.next()) {
				String kind = set.getString(m_kindSpalte);

				// System.out.println(set.getRow() + ": " + kind);
				leafs.add(kind);
				count++;
			}
			stmt.close();

			System.out.println("Leafs read: " + count);

			// then retrieve the hierarchy path for each leaf
			int count2 = 0;
			for (String leaf : leafs) {
				count2++;
				Path path = getPathForLeaf(leaf);
				System.out.println("Retrieve path " + count2);
				m_hierarchyMap.put(leaf, path);
			
			}
			
			// write the hierarchy to the cache file
			ObjectOutputStream output = new ObjectOutputStream(new FileOutputStream(hierarchyFile));
			output.writeObject(m_hierarchyMap);
		}
		
		int count = 0;
		for(Path path : m_hierarchyMap.values()) {
			count++;
			System.out.println(count + " path: " + path);
		}
	}

	// this is the head method invoking the recursive retrieval 
	// of the hierarchy path
	private Path getPathForLeaf(String leaf) throws Exception {

		PreparedStatement prepStmt = m_con.prepareStatement("select "
				+ m_elternSpalte + " from " + m_table + " where "
				+ m_kindSpalte + " = ?");
		// create so far empty path
		Path path = new Path(leaf);
		addParentNode(prepStmt, leaf, path);

		return path;
	}

	// recursive method
	private void addParentNode(PreparedStatement prepStmt, String child,
			Path path) throws Exception {
		prepStmt.setString(1, child);
		ResultSet set = prepStmt.executeQuery();
		String eltern = null;
		boolean hasRow = false;
		while (set.next()) {
			hasRow = true;
			eltern = set.getString(m_elternSpalte);
			path.addHierarchyNode(eltern);
			// integrity check - there must be only one entry
			if (set.getRow() != 1) {
				throw new RuntimeException(
						"Hierarchy Table has more than one entry for child <"
								+ child + ">");
			}
		}

		// if there was an entry, invoke recursive call
		if (hasRow) {
			// if there is a row the parent should not be null
			if (eltern == null) {
				throw new RuntimeException(
						"Hierarchy Table has parent = NULL entry for child <"
								+ child + ">");
			}
			addParentNode(prepStmt, eltern, path);
		}
	}

	public ArrayList<String> getHierarchyNodesForLeaf(String leaf) {
		return m_hierarchyMap.get(leaf).getHierarchyNodes();
	}

}
