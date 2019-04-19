#dplyr tutorial
#https://cran.r-project.org/web/packages/dplyr/vignettes/dplyr.html

library(dplyr)
library(nycflights13)
library(ggplot2)
library(magrittr)
library(gridExtra)

dim(flights)

flights

#filter() to select cases based on their values.
#arrange() to reorder the cases.
#select() and rename() to select variables based on their names.
#mutate() and transmute() to add new variables that are functions of existing variables.
#summarise() to condense multiple values to a single value.
#sample_n() and sample_frac() to take random samples.


#For example, we can select all flights on January 1st with:
filter(flights, month == 1, day == 1)
#This is rougly equivalent to this base R code:
flights[flights$month == 1 & flights$day == 1, ]


arrange(flights, year, month, day)
arrange(flights, desc(arr_delay))


# Select columns by name
select(flights, year, month, day)
# Select all columns between year and day (inclusive)
select(flights, year:day)
# Select all columns except those from year to day (inclusive)
select(flights, -(year:day))


#You can rename variables with select() by using named arguments:
select(flights, tail_num = tailnum)
#But because select() drops all the variables not explicitly mentioned, it's not that useful. 
#Instead, use rename():
rename(flights, tail_num = tailnum)


#Besides selecting sets of existing columns, 
#it's often useful to add new columns that are functions of existing columns. 
#This is the job of mutate():
mutate(flights, 
       gain = arr_delay - dep_delay, 
       speed = distance / air_time * 60
       )
#dplyr::mutate() is similar to the base transform(), 
#but allows you to refer to columns that you've just created:
mutate(flights, 
       gain = arr_delay - dep_delay, 
       gain_per_hour = gain / (air_time / 60)
       )

#If you only want to keep the new variables, use transmute():
transmute(flights, 
          gain = arr_delay - dep_delay,
          gain_per_hour = gain / (air_time / 60)
          )

#The last verb is summarise(). It collapses a data frame to a single row.
summarise(flights,
          delay = mean(dep_delay, na.rm = TRUE)
          )


#You can use sample_n() and sample_frac() to take a random sample of rows: 
#use sample_n() for a fixed number
sample_n(flights, 10)
#and sample_frac() for a fixed fraction.
sample_frac(flights, 0.01)
#Use replace = TRUE to perform a bootstrap sample. 
#If needed, you can weight the sample with the weight argument.


#You may have noticed that the syntax and function of all these verbs are very similar:
#The first argument is a data frame.
#The subsequent arguments describe what to do with the data frame. 
#You can refer to columns in the data frame directly without using $.
#The result is a new data frame



#Grouping affects the verbs as follows:

#grouped select() is the same as ungrouped select(), except that grouping variables are always retained.

#grouped arrange() is the same as ungrouped; unless you set .by_group = TRUE, in which case it orders 
#first by the grouping variables

#mutate() and filter() are most useful in conjunction with window functions
#(like rank(), or min(x) == x). They are described in detail in vignette("window-functions").

#sample_n() and sample_frac() sample the specified number/fraction of rows in each group.

#summarise() computes the summary for each group.


#In the following example, we split the complete dataset into individual planes 
by_tailnum <- group_by(flights, tailnum)
#and then summarise each plane by counting the number of flights (count = n()) 
#and computing the average distance (dist = mean(distance, na.rm = TRUE)) 
#and arrival delay (delay = mean(arr_delay, na.rm = TRUE)). 
delay <- summarise(by_tailnum,
                   count = n(),
                   dist = mean(distance, na.rm = TRUE),
                   delay = mean(arr_delay, na.rm = TRUE))
delay <- filter(delay, count > 20, dist < 2000)
#We then use ggplot2 to display the output.
# Interestingly, the average delay is only slightly related to the
# average distance flown by a plane.
ggplot(delay, aes(dist, delay)) + 
  geom_point(aes(size = count), alpha = 1/2) + 
  geom_smooth() + 
  scale_size_area() +
  theme_minimal()


#You use summarise() with aggregate functions, which take a vector of values and return a single number. 
#There are many useful examples of such functions in base R like 
#min(), max(), mean(), sum(), sd(), median(), and IQR(). dplyr provides a handful of others:
#n(): the number of observations in the current group
#n_distinct(x):the number of unique values in x.
#first(x), last(x) and nth(x, n) - these work similarly to x[1], x[length(x)], and x[n] but give you more control over the result if the value is missing.

#For example, we could use these to find the number of planes 
#and the number of flights that go to each possible destination:
destinations <- group_by(flights, dest)
summarise(destinations,
          planes = n_distinct(tailnum),
          flights = n()
          )


#When you group by multiple variables, each summary peels off one level of the grouping. 
#That makes it easy to progressively roll-up a dataset:
daily <- group_by(flights, year, month, day)
(per_day   <- summarise(daily, flights = n()))
(per_month <- summarise(per_day, flights = sum(flights)))
(per_year  <- summarise(per_month, flights = sum(flights)))
#However you need to be careful when progressively rolling up summaries like this: 
#it's ok for sums and counts, but you need to think about weighting for means and variances 
#(it's not possible to do this exactly for medians).


#The following calls are completely equivalent from dplyr's point of view:
select(flights, year)
select(flights, 1)


#Whereas select() expects column names or positions, mutate() expects column vectors. 
#Let's create a smaller tibble for clarity:
df <- select(flights, year:dep_time)
mutate(df, "year", 2)


#Piping
#If you want to do many operations at once, you either have to do it step-by-step:
a1 <- group_by(flights, year, month, day)
a2 <- select(a1, arr_delay, dep_delay)
a3 <- summarise(a2,
                arr = mean(arr_delay, na.rm = TRUE),
                dep = mean(dep_delay, na.rm = TRUE))
a4 <- filter(a3, arr > 30 | dep > 30)
#Or if you don't want to name the intermediate results, 
#you need to wrap the function calls inside each other:
filter(summarise(select(group_by(flights, year, month, day),
                        arr_delay, dep_delay
                        ),
                 arr = mean(arr_delay, na.rm = TRUE),
                 dep = mean(dep_delay, na.rm = TRUE)
                 ),
       arr > 30 | dep > 30
       )
#To get around this problem, dplyr provides the %>% operator from magrittr. 
#x %>% f(y) turns into f(x, y) so you can use it to rewrite multiple operations 
#that you can read left-to-right, top-to-bottom:
flights %>%
  group_by(year, month, day) %>%
  select(arr_delay, dep_delay) %>%
  summarise(
    arr = mean(arr_delay, na.rm = TRUE),
    dep = mean(dep_delay, na.rm = TRUE)
  ) %>%
  filter(arr > 30 | dep > 30)



#magrittr aside
#https://magrittr.tidyverse.org/
#Basic piping
#x %>% f is equivalent to f(x)
#x %>% f(y) is equivalent to f(x, y)
#x %>% f %>% g %>% h is equivalent to h(g(f(x)))
#x %>% f(y, .) is equivalent to f(y, x)
#x %>% f(y, z = .) is equivalent to f(y, z = x)

iris %>%
  subset(Sepal.Length > mean(Sepal.Length)) %$%
  cor(Sepal.Length, Sepal.Width)


data.frame(z = rnorm(100)) %>%
  ts.plot()

data.frame(z = rnorm(100)) %$%
  ts.plot(z)

p1 <- ggplot(delay, aes(dist, delay)) + 
  geom_point(aes(size = count), alpha = 1/2) + 
  geom_smooth() + 
  scale_size_area() +
  theme_minimal()

p2 <- delay %>%
  filter(dist > 500 & dist <= 1000) %>%
  ggplot(data = ., aes(dist, delay)) + 
  geom_point(aes(size = count), alpha = 1/2) + 
  geom_smooth() + 
  scale_size_area() +
  theme_minimal()


grid.arrange(p1, p2, nrow=1)

grid.arrange(p1, p2, nrow=2)





#Reporting regressions with stargazer
library(stargazer)

data("mtcars")
head(mtcars)
mymodel <- mtcars %>% 
  lm(data = ., formula = mpg ~ cyl + wt)
summary(mymodel)

stargazer(mymodel, type = "text")

glimpse(mtcars)
str(mtcars)


mymodel <- mtcars %>% 
  lm(data = ., formula = mpg ~ cyl + wt + as.factor(vs)*as.factor(am))
summary(mymodel)

stargazer(mymodel, type = "text")
