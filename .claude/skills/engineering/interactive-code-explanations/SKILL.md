---
name: interactive-code-explanations
description: Generate interactive visualizations and animations to explain complex algorithms and reduce cognitive debt
department: engineering
argument-hint: "Create visualization explaining the event filtering state machine logic"
when_to_use: |
  After generating complex code implementations, especially:
  - Algorithms with non-obvious logic flow
  - Data transformations with multiple steps
  - State machines or complex conditionals
  - Code that will be maintained by other developers
  - Educational or documentation purposes
thinking-level: medium
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---

# Interactive Code Explanations Skill

## Problem Statement
AI-generated code creates "cognitive debt" when developers lose intuitive understanding of system logic. This skill addresses that by creating self-explanatory code through interactive visualizations that make complex algorithms intuitively understandable.

## Implementation Strategy

### Post-Generation Hook
Add this prompt after code generation to trigger visualization creation:

Now, create an interactive explanation for the code you just generated:
1. Identify the 2-3 most complex algorithmic concepts in this implementation
2. Design a step-by-step visualization that would help a developer understand:
   - Data flow through the system
   - State transitions
   - Key transformations
3. Choose the most appropriate visualization format:
   - Animated flowchart with code highlighting
   - Data structure visualization with transformations
   - Interactive state machine diagram
   - Timeline showing parallel processes
4. Provide implementation instructions for the visualization

### Optional Documentation Module Integration
# Example integration structure
class InteractiveExplanation:
    def __init__(self, code, complexity_threshold=0.7):
        self.code = code
        self.complexity = self.analyze_complexity()

    def should_explain(self):
        return self.complexity > complexity_threshold

    def generate_visualization(self):
        # Agent generates visualization code here
        pass

    def create_interactive_demo(self):
        # Creates runnable examples
        pass

## Visualization Formats

### 1. Animated Flowcharts
// Example output structure
const visualization = {
    type: "animated_flowchart",
    steps: [
        { code_line: 15, highlight: "input_validation",
          visualization: "Show user input being sanitized" },
        { code_line: 28, highlight: "data_transform",
          visualization: "Animate array map operation" },
        { code_line: 42, highlight: "result_calculation",
          visualization: "Show intermediate values" }
    ],
    interactive_elements: [
        "Pause/play animation",
        "Step through manually",
        "Hover for code details"
    ]
}

### 2. Data Structure Visualizers
For algorithms involving complex data structures:
- Animate tree rotations (AVL, Red-Black trees)
- Show hash table collisions and resolution
- Visualize graph traversals with highlighted paths
- Demonstrate sorting algorithm comparisons

### 3. State Machine Explainer
# Example state machine visualization prompt
"""
Visualize this state machine as an interactive diagram:
- Show all possible state transitions
- Highlight current state with context
- Animate transition triggers
- Show guard conditions on edges
- Allow clicking states to see relevant code
"""

## Example Prompts

### For Sorting Algorithms
After implementing the merge sort algorithm, create an interactive visualization that:
1. Shows the recursive division of the array
2. Animates the merge process with comparison highlights
3. Allows users to:
   - Input their own array
   - Step through at their own pace
   - See time complexity at each step
4. Compare with bubble sort side-by-side

### For Graph Algorithms
Following your Dijkstra's algorithm implementation, generate:
1. An interactive graph where nodes can be dragged
2. Real-time visualization of the algorithm's frontier
3. Highlighting of the shortest path as it's discovered
4. A sidebar showing the priority queue state
5. Ability to add/remove nodes and edges to test edge cases

### For Database Queries
After writing the complex SQL query, create:
1. A visual representation of table joins
2. Animation of how WHERE clauses filter data
3. Step-by-step explanation of aggregation
4. Sample data that flows through each step
5. Comparison with alternative query approaches

## Integration Guidelines

### As Standalone Documentation
## Interactive Explanation
[View interactive visualization](visualization.html)

### Key Insights:
1. **Pattern**: The algorithm uses divide-and-conquer
2. **Edge Case**: Watch for overflow in line 34
3. **Optimization**: Memoization reduces complexity from O(2^n) to O(n)

### Try It Yourself:
# Runnable example with sliders
from visualization import interactive_demo
interactive_demo.run_with_custom_input([5, 2, 8, 1])

### As Code Comments
def complex_algorithm(data):
    """
    INTERACTIVE EXPLANATION:
    [Step 1]: Normalize input → Visual: Data standardization curve
    [Step 2]: Apply transformation → Visual: Matrix multiplication grid
    [Step 3]: Aggregate results → Visual: Rolling average graph

    TO VISUALIZE: Run `python -m explainer module.py:complex_algorithm`
    """

### Web-Based Visualization
Generate HTML/JavaScript visualizations that can be:
1. Embedded in documentation
2. Run locally without setup
3. Exported as GIFs for static documentation
4. Hosted as interactive examples

## Best Practices

### When to Generate Explanations
- Code complexity score exceeds threshold (cyclomatic complexity > 10)
- Algorithm has educational value
- Code will be maintained by multiple developers
- Implementation has non-obvious optimizations

### What to Visualize
1. **Data Flow**: How data moves through the system
2. **State Changes**: Critical state transitions
3. **Performance Characteristics**: Time/space complexity
4. **Edge Cases**: How the code handles special conditions
5. **Alternative Approaches**: What other options exist

### Accessibility Considerations
- Provide text descriptions for all visual elements
- Ensure color-blind friendly palettes
- Include keyboard navigation
- Offer export to text-based formats

## Example Output Structure

explanation_for: "QuickSort Implementation"
visualization_type: "interactive_animation"
components:
  - name: "Partition Visualization"
    format: "bar chart animation"
    interactive_features:
      - "Pause at any step"
      - "Adjust animation speed"
      - "Highlight pivot element"

  - name: "Recursion Tree"
    format: "collapsible tree diagram"
    shows: "Recursive calls and their subproblems"

  - name: "Complexity Analysis"
    format: "live updating chart"
    compares: "Best/Average/Worst cases"

integration:
  as_html: "quicksort_visualization.html"
  as_widget: "Embeddable iframe provided"
  as_code: "Python visualization script included"

## Testing the Explanations
Before delivering visualizations, verify they:
1. Accurately represent the algorithm
2. Handle edge cases correctly
3. Are performant with reasonable input sizes
4. Include "reset" functionality
5. Work without external dependencies when possible

This skill transforms code from a static artifact into an interactive learning tool, reducing cognitive debt and making complex systems understandable at a glance.
