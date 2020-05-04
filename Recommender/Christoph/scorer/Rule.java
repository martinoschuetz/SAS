package scorer;

/**
 * This class holds a single rule and the implied recommendation (consequence of the rule).
 * Further the statistics are stored in this class.
 *
 */
public class Rule {
	
	String m_rule;
	
	public String getRule() {
		return m_rule;
	}

	String m_recommendation;
	float m_support;
	float m_confidence;
	float m_lift;
	
	public Rule(String rule, String recommendation, float support, float confidence, float lift) {
		m_rule = rule;
		m_recommendation = recommendation;
		m_support = support;
		m_confidence = confidence;
		m_lift = lift;
	}
	
	@Override
	public String toString() {
		return "Recommendation: " + m_recommendation + " | Supp: " + m_support + " | Conf: " + m_confidence + " | Lift: " + m_lift + " | Rule: " + m_rule;
	}

}
