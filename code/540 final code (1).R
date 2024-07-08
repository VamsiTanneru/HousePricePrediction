library(tidyverse)
library(ggplot2)
library(outliers)
library(readr)
library(broom)
library(corrplot)
library(jtools)

getwd()

#read data set
house_p <- read.csv("kc_house_data.csv")
hpnew <- house_p %>%
  select(date, price, bedrooms, bathrooms, sqft_living, sqft_lot,
         floors, condition, grade, sqft_above, sqft_basement, yr_built,
         yr_renovated) %>%
  mutate(bedrooms = factor(bedrooms),
         bathrooms = factor(round(bathrooms)),
         floors = factor(floors),
         condition = factor(condition),
         grade = factor(grade))
str(hpnew)

summary(hpnew) #summary of data

#let us see how the prices are distributed on different number of bedrooms
ggplot(hpnew, aes(bedrooms, price)) +
  geom_boxplot() +
  labs(x = "Bedrooms",
       y = "Price",
       title = "Price distribution among bedrooms") +
  scale_y_continuous(labels = scales::comma)

#Removing outliers
hpnew <- as.data.frame(hpnew)
cols_to_clean <- c(2,3,4,5,6,10,11)
for (i in cols_to_clean) {
  otlrs <- boxplot.stats(hpnew[, i])$out
  o_indic <- which(hpnew[, i] %in% otlrs)
  hpotr <- hpnew[-o_indic, ]
}
head(tibble(hpotr), 10)

#first visualisation will be scatter plot of Price by Square Feet of Living
#Relationship is almost linear like
ggplot(hpotr, aes(sqft_living, price)) +
  geom_point() +
  geom_smooth(formula = y ~ x,
              method = "lm",
              se = FALSE) +
  labs(x = "Square Feet of Living Area",
       y = "Price") +
  scale_y_continuous(labels = scales::comma)

#Now let's label the years of construction
hpotr <- hpotr %>%
  filter(bedrooms != 33) %>%
  mutate(decades_built = case_when(yr_built < 1940 ~ "< 1940",
                                   yr_built >= 1940 & yr_built < 1960 ~ "1940 - 1960",
                                   yr_built >= 1960 & yr_built < 1980 ~ "1960 - 1980",
                                   yr_built >= 1980 & yr_built < 2000 ~ "1980 - 2000",
                                   yr_built >= 2000 ~ "2000 - 2015"))
head(hpotr)
#We can observe that our data is almost eavenly spread based on year built
#that means that our future visualisations on that basis will not be biased

#lets see distribution of houses by year built
ggplot(hpotr, aes(decades_built)) +
  geom_bar() +
  labs(x = "Year the house was built in",
       y = "Count",
       title = "Distribution of houses by year built")

#prices on sqft_living, split by decades and colored by floors
hpotr %>%
  ggplot(aes(sqft_living, price)) +
  geom_point(aes(color = floors),
             alpha = 0.7) +
  geom_smooth(method = "lm", 
              formula = y ~ x,
              se = FALSE,
              colour = "#2B5D87") +
  labs(x = "Square feet of living",
       y = "Price ($)",
       title = "Square Feet of Living plotted by Price ($), Coloured by Number of Floors",
       color = "Floors") +
  scale_y_continuous(labels = scales::comma) +
  facet_wrap(~ decades_built)

#prices on sqft_living, split by decades and colored by bedrooms
hpotr %>%
  filter(bedrooms %in% c(1:7)) %>%
  ggplot(aes(sqft_living, price)) +
  geom_point(aes(color = bedrooms),
             alpha = 0.7) +
  geom_smooth(method = "lm", 
              formula = y ~ x,
              se = FALSE,
              colour = "#2B5D87") +
  labs(x = "Square feet of living",
       y = "Price ($)",
       title = "Square Feet of Living plotted by Price ($), coloured by Bedrooms",
       color = "Bedrooms") +
  scale_y_continuous(labels = scales::comma) +
  facet_wrap(~ decades_built)

#correlation
correl <- cor(house_p[, -c(1, 2)])
corrplot(correl, 
         type = "upper",
         order = "hclust",
         tl.col = "black",
         tl.srt = 45)

#splitting data
nRows <- nrow(hpotr)
slc <- sample(nRows, size = nRows * 0.75)
train <- hpotr[slc, ]
test <- hpotr[-slc, ]
head(train, 10)
head(test, 10)

#regerssion model with single variable
srm <- price ~ sqft_living
model1 <- lm(srm, data = train)
models1 <- glance(model1)
models1$model <- "Simple linear regression model"
models1
summ(model1)
test$pred <- predict(model1, test)
residual1 <- test$price - test$pred
rmse1 <- sqrt(mean(residual1 ^ 2))
models1$rmse <- rmse1
c(round(rmse1), round(sd(test$price)))
ggplot(test, aes(pred, price)) +
  geom_point() +
  geom_smooth(method = "lm",
              formula = y ~ x,
              se = FALSE,
              color = "#2B5D87") +
  scale_x_log10() +
  scale_y_log10() +
  coord_fixed() +
  labs(x = "log(Predicted price)",
       y = "log(Actual price)",
       title = "Simple Linear Model Predictions",
       subtitle = "R^2 = 0.46")

#regeression model with selected variables
mlr1 <- price ~ bedrooms + bathrooms + sqft_living + sqft_lot + floors
model2 <- lm(mlr1, data = train)
models2 <- bind_rows(models1, glance(model2))
models2[2, 13] <- "Multiple regression model with selected features"
glance(model2)
summ(model2)
getRmse <- function(actual, pred){
  res <- actual - pred
  return(sqrt(mean(res ^ 2)))
}
test$pred <- as.numeric(predict(model2, test))
models2[2, 14] <- getRmse(test$price, test$pred)
c(round(getRmse(test$price, test$pred)),
  round(sd(test$price)))
ggplot(test, aes(pred, price)) +
  geom_point() +
  geom_smooth(method = "lm",
              formula = y ~ x,
              se = FALSE,
              color = "#2B5D87") +
  scale_x_log10() +
  scale_y_log10() +
  coord_fixed() +
  labs(x = "log(Predicted price)",
       y = "log(Actual price)",
       title = "Multiple Linear Model with Selected Features",
       subtitle = "R^2 = 0.52")

#regerssion model with almost all variables
clns <- train %>%
  select(-c(date, price)) %>%
  colnames()
clns <- paste(clns, collapse = ' + ')
fmla <- as.formula(paste("price~", paste(clns, collapse="+")))
mlr2 <- lm(fmla, data = train)
models3 <- bind_rows(models2, glance(mlr2))
models3[3, 13] <- "Multiple regression model with almost all features"
glance(mlr2)
summ(mlr2)
test$pred <- as.numeric(predict(mlr2, test))
models3[3, 14] <- getRmse(test$price, test$pred)
c(round(getRmse(test$price, test$pred)),
  round(sd(test$price)))
ggplot(test, aes(pred, price)) +
  geom_point() +
  geom_smooth(method = "lm",
              formula = y ~ x,
              se = FALSE,
              color = "#2B5D87") +
  scale_x_log10() +
  scale_y_log10() +
  coord_fixed() +
  labs(x = "log(Predicted price)",
       y = "log(Actual price)",
       title = "Multiple Linear Model with Almost All Features",
       subtitle = "R^2 = 0.64")
