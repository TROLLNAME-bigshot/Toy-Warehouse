using System.ComponentModel.DataAnnotations;

namespace WarehouseAPI.DTOs.Products;

public class ProductCreateDto
{
    [Required(ErrorMessage = "Название обязательно")]
    [MaxLength(200)]
    /// <example>Молоко 1л</example>
    public string Name { get; set; } = string.Empty;

    [Required(ErrorMessage = "Артикул обязателен")]
    [MaxLength(50)]
    /// <example>MLK-001</example>
    public string Article { get; set; } = string.Empty;

    [Required(ErrorMessage = "Единица измерения обязательна")]
    [MaxLength(20)]
    /// <example>шт</example>
    public string Unit { get; set; } = string.Empty;  // шт, кг, л и т.д.

    [Range(0, double.MaxValue, ErrorMessage = "Цена не может быть отрицательной")]
    /// <example>89.90</example>
    public decimal Price { get; set; }
}