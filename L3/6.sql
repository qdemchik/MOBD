WITH RECURSIVE category_tree AS (
    
    SELECT id, name, parent_category_id, 1 AS level
    FROM categories
    WHERE name = 'Электроника'
    
    UNION ALL
    
  
    SELECT c.id, c.name, c.parent_category_id, ct.level + 1
    FROM categories c
    INNER JOIN category_tree ct ON c.parent_category_id = ct.id
)
SELECT * FROM category_tree ORDER BY level, name;