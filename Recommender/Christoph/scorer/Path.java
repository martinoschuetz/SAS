package scorer;

import java.io.Serializable;
import java.util.ArrayList;

/**
 * This class represents a path from a leaf node upwards the hierarchy.
 * 
 * @author Administrator
 *
 */
public class Path implements Serializable{
	
	// stores the leaf product
	String m_leaf;
	// stores the hierarchy nodes (NO leaf)
	ArrayList<String> m_hierarhcyNodes;
	
	public Path(String leaf) {
		m_leaf = leaf;
		m_hierarhcyNodes = new ArrayList<String>();
	}
	
	public void addHierarchyNode(String hierarchyNode) {
		m_hierarhcyNodes.add(hierarchyNode);
	}
	
	public ArrayList<String> getHierarchyNodes()  {
		return m_hierarhcyNodes;
	}
	
	@Override
	public String toString() {
		StringBuffer buf = new StringBuffer();
		buf.append(m_leaf);
		
		for(String node : m_hierarhcyNodes) {
			buf.append(" -> ").append(node);
		}
		return buf.toString();
	}

}
