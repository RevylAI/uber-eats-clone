import Foundation

enum Catalog {
    static let restaurants: [Restaurant] = [
        Restaurant(id: "burger", name: "Super Duper Burgers", cuisine: "Burgers • American", rating: "4.8 (2,000+)", minutes: "15–25", deliveryFee: 99, image: "burger", offer: "Buy 1, get 1 free", menu: [
            MenuItem(id: "super-burger", name: "Super Burger", detail: "Two all-natural beef patties, aged cheddar, lettuce, tomato, and our signature Super sauce.", price: 1195, image: "burger", category: "Most popular", popular: true),
            MenuItem(id: "chicken", name: "Crispy Chicken Sandwich", detail: "Golden crispy chicken, crunchy slaw, pickles, and house-made herb mayo.", price: 1295, image: "chicken", category: "Most popular", popular: true),
            MenuItem(id: "fries", name: "Garlic Fries", detail: "Golden fries tossed with fresh garlic, parsley, and sea salt.", price: 495, image: "fries", category: "Sides", popular: true),
            MenuItem(id: "salad", name: "Garden Greens", detail: "Seasonal greens, avocado, cucumber, and lemon vinaigrette.", price: 1095, image: "salad", category: "Sides", popular: false),
            MenuItem(id: "drink", name: "Strawberry Shake", detail: "Real strawberries blended with creamy organic vanilla ice cream.", price: 695, image: "dessert", category: "Drinks & sweets", popular: false)
        ]),
        Restaurant(id: "pizza", name: "Tony’s Pizza Napoletana", cuisine: "Pizza • Italian", rating: "4.9 (1,500+)", minutes: "25–35", deliveryFee: 149, image: "pizza", offer: "$5 off orders $25+", menu: [
            MenuItem(id: "margherita", name: "Margherita", detail: "San Marzano tomatoes, fresh mozzarella, basil, and extra virgin olive oil.", price: 1850, image: "pizza", category: "Most popular", popular: true),
            MenuItem(id: "pepperoni", name: "Classic Pepperoni", detail: "Wood-fired crust, rich tomato sauce, mozzarella, and crisp pepperoni.", price: 2150, image: "pizza", category: "Most popular", popular: true),
            MenuItem(id: "pizza-salad", name: "Little Gem Caesar", detail: "Little gem lettuce, parmesan, croutons, and creamy Caesar dressing.", price: 950, image: "salad", category: "Sides", popular: false)
        ]),
        Restaurant(id: "sushi", name: "Sushi Time", cuisine: "Sushi • Japanese", rating: "4.7 (800+)", minutes: "20–30", deliveryFee: 99, image: "sushi", offer: "Free delivery on $20+", menu: [
            MenuItem(id: "salmon", name: "Salmon Lovers Set", detail: "Fresh salmon nigiri, salmon avocado rolls, ginger, and wasabi.", price: 2295, image: "sushi", category: "Most popular", popular: true),
            MenuItem(id: "roll", name: "California Roll", detail: "Crab, avocado, cucumber, and toasted sesame. Eight pieces.", price: 1095, image: "sushi", category: "Most popular", popular: true)
        ]),
        Restaurant(id: "tacos", name: "La Taqueria", cuisine: "Mexican • Tacos", rating: "4.9 (3,000+)", minutes: "15–25", deliveryFee: 49, image: "tacos", offer: "Top rated in your neighborhood", menu: [
            MenuItem(id: "taco", name: "Street Taco Trio", detail: "Three warm corn tortillas with grilled carne asada, fresh cilantro, and onion.", price: 1395, image: "tacos", category: "Most popular", popular: true),
            MenuItem(id: "burrito", name: "Mission Burrito", detail: "Grilled chicken, beans, rice, pico de gallo, guacamole, and crema.", price: 1495, image: "tacos", category: "Most popular", popular: true)
        ]),
        Restaurant(id: "green", name: "sweetgreen", cuisine: "Healthy • Salads • Vegetarian", rating: "4.8 (900+)", minutes: "10–20", deliveryFee: 99, image: "salad", offer: "Fresh picks, feel-good food", menu: [
            MenuItem(id: "harvest", name: "Harvest Bowl", detail: "Roasted sweet potatoes, apples, goat cheese, wild rice, and balsamic vinaigrette.", price: 1595, image: "salad", category: "Most popular", popular: true)
        ]),
        Restaurant(id: "bakery", name: "Tartine Bakery", cuisine: "Bakery • Breakfast • Coffee", rating: "4.9 (1,200+)", minutes: "20–30", deliveryFee: 149, image: "dessert", offer: "A little something sweet", menu: [
            MenuItem(id: "cake", name: "Seasonal Berry Cake", detail: "Soft vanilla sponge, whipped cream, and fresh seasonal berries.", price: 895, image: "dessert", category: "Most popular", popular: true)
        ])
    ]
}
