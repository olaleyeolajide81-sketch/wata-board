#![no_std]
use soroban_sdk::{contract, contractimpl, Address, Env, String, token, Map, Vec, i64};

#[contract]
pub struct NepaBillingContract;

#[derive(Clone)]
#[contracttype]
pub struct Review {
    pub reviewer: Address,
    pub rating: i64,          // 1-5 stars
    pub comment: String,     // Review text
    pub timestamp: i64,      // Block timestamp
    pub transaction_hash: String, // For verification
}

#[derive(Clone)]
#[contracttype]
pub struct RatingStats {
    pub total_reviews: i64,
    pub average_rating: i64, // Stored as integer (e.g., 45 for 4.5 stars)
    pub rating_counts: Vec<i64>, // [1-star, 2-star, 3-star, 4-star, 5-star] counts
}

#[contractimpl]
impl NepaBillingContract {
    
    pub fn pay_bill(env: Env, from: Address, token_address: Address, meter_id: String, amount: i128) {
        // 1. Verify the user authorized this payment
        from.require_auth();

        // 2. Initialize the Token client (for XLM or USDC)
        let token_client = token::Client::new(&env, &token_address);

        // 3. Move the tokens from the User to the Contract
        token_client.transfer(&from, &env.current_contract_address(), &amount);

        // 4. Update the meter record (using i128 for larger money values)
        let current_total: i128 = env.storage().persistent().get(&meter_id).unwrap_or(0);
        env.storage().persistent().set(&meter_id, &(current_total + amount));
    }

    pub fn get_total_paid(env: Env, meter_id: String) -> i128 {
        env.storage().persistent().get(&meter_id).unwrap_or(0)
    }

    // New rating and review functions
    pub fn submit_review(
        env: Env, 
        reviewer: Address, 
        rating: i64, 
        comment: String,
        transaction_hash: String
    ) {
        // 1. Verify the reviewer authorized this review
        reviewer.require_auth();

        // 2. Validate rating (1-5)
        if rating < 1 || rating > 5 {
            panic!("Rating must be between 1 and 5");
        }

        // 3. Validate comment length (max 500 characters)
        let comment_len = comment.len();
        if comment_len > 500 {
            panic!("Review comment too long (max 500 characters)");
        }

        // 4. Check if user has already submitted a review
        let reviews_key = String::from_str(&env, "reviews");
        let reviews: Map<Address, Review> = env.storage().persistent().get(&reviews_key).unwrap_or(Map::new(&env));
        
        if reviews.contains_key(reviewer.clone()) {
            panic!("User has already submitted a review");
        }

        // 5. Create the review
        let new_review = Review {
            reviewer: reviewer.clone(),
            rating,
            comment,
            timestamp: env.ledger().timestamp(),
            transaction_hash,
        };

        // 6. Store the review
        let mut updated_reviews = reviews;
        updated_reviews.set(reviewer.clone(), new_review);
        env.storage().persistent().set(&reviews_key, &updated_reviews);

        // 7. Update rating statistics
        self.update_rating_stats(&env, rating);
    }

    pub fn get_user_review(env: Env, reviewer: Address) -> Option<Review> {
        let reviews_key = String::from_str(&env, "reviews");
        let reviews: Map<Address, Review> = env.storage().persistent().get(&reviews_key).unwrap_or(Map::new(&env));
        reviews.get(reviewer)
    }

    pub fn get_all_reviews(env: Env) -> Vec<Review> {
        let reviews_key = String::from_str(&env, "reviews");
        let reviews: Map<Address, Review> = env.storage().persistent().get(&reviews_key).unwrap_or(Map::new(&env));
        
        let mut review_list = Vec::new(&env);
        for (_, review) in reviews.iter() {
            review_list.push_back(review);
        }
        
        review_list
    }

    pub fn get_rating_stats(env: Env) -> RatingStats {
        let stats_key = String::from_str(&env, "rating_stats");
        env.storage().persistent().get(&stats_key).unwrap_or(RatingStats {
            total_reviews: 0,
            average_rating: 0,
            rating_counts: Vec::from_array(&env, &[0, 0, 0, 0, 0]),
        })
    }

    pub fn verify_review(env: Env, reviewer: Address, transaction_hash: String) -> bool {
        if let Some(review) = self.get_user_review(env.clone(), reviewer) {
            review.transaction_hash == transaction_hash
        } else {
            false
        }
    }

    fn update_rating_stats(&self, env: &Env, new_rating: i64) {
        let stats_key = String::from_str(&env, "rating_stats");
        let mut stats: RatingStats = env.storage().persistent().get(&stats_key).unwrap_or(RatingStats {
            total_reviews: 0,
            average_rating: 0,
            rating_counts: Vec::from_array(&env, &[0, 0, 0, 0, 0]),
        });

        // Update total reviews
        stats.total_reviews += 1;

        // Update rating counts (convert 1-5 to 0-4 index)
        let rating_index = (new_rating - 1) as usize;
        let mut counts = stats.rating_counts;
        let current_count = counts.get(rating_index as u32).unwrap_or(0);
        counts.set(rating_index as u32, current_count + 1);
        stats.rating_counts = counts;

        // Calculate new average rating (stored as integer, e.g., 45 for 4.5)
        let mut total_rating = 0;
        let mut total_count = 0;
        for i in 0..5 {
            let count = stats.rating_counts.get(i as u32).unwrap_or(0);
            total_rating += (i as i64 + 1) * count;
            total_count += count;
        }

        if total_count > 0 {
            stats.average_rating = (total_rating * 10) / total_count; // Store as *10 for decimal precision
        }

        env.storage().persistent().set(&stats_key, &stats);
    }
}