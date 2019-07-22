CREATE SCHEMA scoop
	AUTHORIZATION postgres;

/* Install the uuid generator*/
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

/* Auto Update Timestamp Function */
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

/*----------------------------------------END OF FUNCTIONS AND TRIGGERS----------------------------------------*/


/*------------------------------------------------------------START OF STATIC TABLES------------------------------------------------------------*/

/* This table contains the names (in French and English) of the divisions of CFIA */
CREATE TABLE scoop.divisions(
	divisionId serial,
	division_en VARCHAR(255),
	division_fr VARCHAR(255),
	createdDate TIMESTAMPTZ DEFAULT NOW(),
	modifiedDate TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY (divisionId)
);

/* This table contains a list of social media */
CREATE TABLE scoop.socialMedia (
	socialMediaId serial,
	socialMediaName VARCHAR(255),
	socialMediaSymbol bytea,

    PRIMARY KEY (socialMediaId)
);

/* This table contains a list of social media */
CREATE TABLE scoop.positions (
	positionId serial,
	positionName VARCHAR(255),
	
    PRIMARY KEY (positionId)
);

/* This table contains the names (in French and English) of the buildings that CFIA servants work in/at */
CREATE TABLE scoop.buildings(
	buildingId serial,
	buildingName_en VARCHAR(255),
	buildingName_fr VARCHAR(255),
	address VARCHAR(255),
	city VARCHAR(255),
	province VARCHAR(2),
	postalCode VARCHAR(6),

    PRIMARY KEY (buildingId)
);

/* This table contains a list of genders */
CREATE TABLE scoop.genders (
	genderId serial,
	genderName VARCHAR(255),
	genderInfo VARCHAR(255),

    PRIMARY KEY (genderId)
);

/*------------------------------------------------------------END OF STATIC TABLES------------------------------------------------------------*/

/*------------------------------------------------------------START OF TABLES-----------------------------------------------------*/

/* This table contains all the information relevant to the users */
CREATE TABLE scoop.users(
	userId uuid DEFAULT uuid_generate_v4(),
	firstName VARCHAR(255),
	lastName VARCHAR(255),
	email VARCHAR(255),
	passwordHash VARCHAR(512),
	salt VARCHAR(255),
	dateOfBirth DATE,
	genderId INTEGER REFERENCES scoop.genders(genderId),
	divisionId INTEGER REFERENCES scoop.divisions(divisionId),
	buildingId INTEGER REFERENCES scoop.buildings(buildingId),
	positionId INTEGER REFERENCES scoop.positions(positionId),
	profileImage VARCHAR(255),
	address VARCHAR(255),
	city VARCHAR(255),
	province VARCHAR(2),
	postalCode VARCHAR(6),
	createdDate TIMESTAMPTZ DEFAULT NOW(),
	modifiedDate TIMESTAMPTZ DEFAULT NOW(),
	modifiedBy uuid,
	userStatus INTEGER,

    PRIMARY KEY (userId)
);

/* This table contains all users' social media links  list of social media */
CREATE TABLE scoop.userSocial (
	socialMediaId INTEGER NOT NULL REFERENCES scoop.socialMedia(socialMediaId),
	userId uuid NOT NULL REFERENCES scoop.users(userId),
	url VARCHAR(255),
	activeStatus INTEGER DEFAULT 1,

	PRIMARY KEY (socialmediaid, userId)
);

/* This table contains all the previous posts searched by each individual user */
CREATE TABLE scoop.searchHistory (
	searchHistoryId serial,
	userId uuid REFERENCES scoop.users(userId),
	userSearch VARCHAR(255),
    activeStatus INTEGER DEFAULT 1,
    createdDate TIMESTAMPTZ DEFAULT NOW(),
	
    PRIMARY KEY (searchhistoryid)
);

CREATE TABLE scoop.postCommentReply (
    activityId uuid DEFAULT uuid_generate_v4(),
  	userid uuid REFERENCES scoop.users(userid),
  	activityType INTEGER NOT NULL, 
    postTitle VARCHAR (255),
    postText VARCHAR(255),
    postImage bytea,
    activeStatus INTEGER DEFAULT 1,
    createdDate TIMESTAMPTZ DEFAULT NOW(),
	modifiedDate TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY (activityId)
);

CREATE TABLE scoop.likes (
    likeId uuid DEFAULT uuid_generate_v4(),
    activityId uuid REFERENCES scoop.postCommentReply(activityId),
  	userid uuid REFERENCES scoop.users(userid),
    likeType INTEGER,
    activeStatus INTEGER DEFAULT 1,
    createdDate TIMESTAMPTZ DEFAULT NOW(),
	modifiedDate TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY (likeId)
);

CREATE TABLE scoop.reportTable (
    activityId uuid REFERENCES scoop.postCommentReply(activityId),
    userId uuid REFERENCES scoop.users(userId),
    reason VARCHAR(255),
    activeStatus INTEGER DEFAULT 1,
    dateCreated TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY (activityId, userId)
);

/* This table contains all the saved posts by each individual user */
CREATE TABLE scoop.savedPosts (
	activityId uuid REFERENCES scoop.postCommentReply(activityId),
	userId uuid REFERENCES scoop.users(userId),
	activeStatus INTEGER DEFAULT 1,

    PRIMARY KEY (activityId, userId)
);

/* This table contains all the notifications that are sent/received */
CREATE TABLE scoop.notifications (
	notificationId uuid DEFAULT uuid_generate_v4(),
	userId uuid REFERENCES scoop.users(userId),
	activityId uuid REFERENCES scoop.postCommentReply(activityId),
    likeId uuid REFERENCES scoop.likes(likeId),
	activeStatus INTEGER DEFAULT 1,
    createdDate TIMESTAMPTZ DEFAULT NOW(),
	modifiedDate TIMESTAMPTZ DEFAULT NOW(),
	
	PRIMARY KEY (notificationId)
);

/*------------------------------------------------------------END OF TABLES------------------------------------------------------------*/

/*---------------------ALTERATIONS----------------------*/
-- From Maxwell: need ActivityID for postcommentreply to reference post being commented or comment being replied
ALTER TABLE scoop.postcommentreply ADD otherActivityID uuid REFERENCES scoop.postcommentreply(activityID);

-- From Timmy: delete city, province, address off usertable (personally wouldnt want home address in a public directInfo)
ALTER TABLE scoop.users DROP address;
ALTER TABLE scoop.users DROP city;
ALTER TABLE scoop.users DROP province;
ALTER TABLE scoop.users DROP postalcode;

-- Dont need
ALTER TABLE scoop.socialmedia DROP socialmediasymbol;

INSERT INTO scoop.socialmedia (socialmedianame) VALUES ('Facebook');
INSERT INTO scoop.socialmedia (socialmedianame) VALUES ('Instagram');
INSERT INTO scoop.socialmedia (socialmedianame) VALUES ('LinkedIn');
INSERT INTO scoop.socialmedia (socialmedianame) VALUES ('Twitter');


-- Change postimage type in postcommentreply. Using image path now instead of bytearray
ALTER TABLE scoop.postcommentreply DROP postimage;
ALTER TABLE scoop.postcommentreply ADD postimagepath VARCHAR(255); 

-- Renaming as replies were removed (for now)
ALTER TABLE scoop.postcommentreply RENAME TO postcomment;

--alters name of otheractivity id
ALTER TABLE scoop.postcomment RENAME COLUMN otherActivityID TO activityreference;


--creates a enum type of which feed you're posting from 
CREATE TYPE feedtype AS ENUM('official', 'community');
ALTER TABLE scoop.postcomment ADD COLUMN feed feedtype;

--Y'all welcome
--sequelize-auto -h localhost -d scoopDB -u postgres -x 123456 -p 5432 --dialect postgres -o './models/ -s scoop -t buildings, divisions,genders, likes, notifications, positions, postcomment, reporttable, savedposts, searchhistory, socialmedia, users, usersocial

--Creates an enum type for whether the account is certified to post in official
CREATE TYPE certifiedtype AS ENUM('yes', 'no');
ALTER TABLE scoop.users ADD COLUMN officialcertified certifiedtype;

--create an official notifications feed for notifications sent to all users
CREATE TABLE scoop.officialnotifs(
 	notificationId uuid DEFAULT uuid_generate_v4(),
	activityId uuid REFERENCES scoop.postComment(activityId),
	activeStatus INTEGER DEFAULT 1,
    createdDate TIMESTAMPTZ DEFAULT NOW(),
	modifiedDate TIMESTAMPTZ DEFAULT NOW(),
	
	PRIMARY KEY (notificationId)
  );
 
 -- add createddate column to sort savedposts 
ALTER TABLE scoop.savedposts ADD COLUMN createdDate TIMESTAMPTZ DEFAULT NOW();

-- add body column for details of report
ALTER TABLE scoop.reporttable ADD COLUMN body VARCHAR(255); 
-- rename datecreated column to createdDate column to be more consistent with rest of database
ALTER TABLE scoop.reporttable DROP datecreated;
ALTER TABLE scoop.reporttable ADD createdDate TIMESTAMPTZ DEFAULT NOW();

  
--Creates the tsvector column in postcomment for full text searching
ALTER TABLE scoop.postcomment ADD COLUMN searchtokens TSVECTOR;


